module ApplicationHelper
  # Expects that the private key in PEM format. Converts the newlines
  PRIVATE_KEY = ( ENV['GITHUB_PRIVATE_KEY'] && !ENV['GITHUB_PRIVATE_KEY'].empty? ) ? OpenSSL::PKey::RSA.new(ENV['GITHUB_PRIVATE_KEY'].gsub('\n', "\n")) : ""

  # Your registered app must have a secret set. The secret is used to verify
  # that webhooks are sent by GitHub.
  WEBHOOK_SECRET = ENV['GITHUB_WEBHOOK_SECRET']

  # The GitHub App's identifier (type integer) set when registering an app.
  APP_IDENTIFIER = ENV['GITHUB_APP_IDENTIFIER']

  # Default configuration
  TESTS_DIR = 'test-suites/'
  TESTS_MAPPING_FILE = 'config/mapping.json' 
  TESTS_REPO = 'wordpress-mobile/test-cases'
  
  def handle_pullrequest_opened_event(payload)
    repo = payload['repository']['full_name']
    pr_number = payload['pull_request']['number']

    logger.debug('A PR was opened in repo: ' + repo.to_s + ', PR number: ' + pr_number.to_s)

    fetch_config(repo, logger)
    mapping_json = fetch_mapping_json()
    matched_files = find_matched_testcase_files_from_pr(repo, pr_number, mapping_json)
    test_content = create_test_content(matched_files)

    if matched_files.count > 0
      create_pull_request_review(repo, pr_number, test_content)
    end
  end

  def fetch_mapping_json()
    mapping = Octokit.contents(@config[:tests_repo], :path => @config[:mapping_file])
    content = mapping['content']
    plain = Base64.decode64(content)
    json = JSON.parse(plain)
  end

  def default_config()
    {
      tests_dir: 'test-suites/',
      mapping_file: 'config/mapping.json',
      tests_repo: 'wordpress-mobile/test-cases'
    }
  end

  def fetch_config(repo_name, logger)
    config_file = '.github/test-case-reminder.json'
    @config = default_config
    
    begin
      response = Octokit.contents(repo_name, :path => config_file)
    rescue => exception
      logger.debug('No config file found. Falling back to default values')
      return;
    end

    content = response[:content]
    plain = Base64.decode64(content)
    json = JSON.parse(plain, {symbolize_names: true})
    logger.debug("Found a config file for #{ repo_name }: #{ json }")

    @config.each do |key, value|
      @config[key] = json[key] if ( json[key] )
    end
  end

  def create_pull_request_review(repo, pr_number, test_content)
    options = { event: 'COMMENT', body: test_content }
    @installation_client.create_pull_request_review(repo, pr_number, options)
    logger.debug('Created pull request review:')
    logger.debug(test_content)
  end

  def find_matched_testcase_files_from_pr(repo, pr_number, mapping_json)
    files = @installation_client.pull_request_files(repo, pr_number)
    matched_files = find_matched_testcase_files(files, mapping_json, logger)
  end

  def find_matched_testcase_files(files, mapping_json, logger)
    logger.debug('Starting to run regex phrases on file names from the PR.')
    matched_files = []
    files.each { |file| puts
      filename = file['filename']
      logger.debug('filename: ' + filename.to_s)
      mapping_json.each { |item| puts
        regex = Regexp.new(item['regex'].to_s)
        logger.debug('regex: ')
        logger.debug(regex)
        if regex.match?(filename)
          logger.debug('match! ' + item['testFile'].join(', '))
          matched_files << item['testFile']
        end
      }
    }
    matched_files = matched_files.flatten.uniq
  end

  def create_test_content(matched_files) 
    testContent = "Here are some suggested test cases for this PR. \n\n"
    matched_files.each { |file| puts
          testFile = Octokit.contents(@config[:tests_repo], :path => @config[:tests_dir] + file)
          testContent = testContent + Base64.decode64(testFile['content'])
    }
    testContent = testContent + "\n\n" + " If you think that suggestions should be improved please edit the configuration file [here](https://github.com/wordpress-mobile/test-cases/blob/master/config/mapping.json). You can also modify/add [test-suites](https://github.com/wordpress-mobile/test-cases/tree/master/test-suites) to be used in the [configuration](https://github.com/wordpress-mobile/test-cases/blob/master/config/mapping.json).\n\n If you are a beginner in mobile platforms follow [build instructions](https://github.com/wordpress-mobile/test-cases/blob/master/README.md#build-instructions)."
  end

  # Saves the raw payload and converts the payload to JSON format
  def get_payload_request(request)
    # request.body is an IO or StringIO object
    # Rewind in case someone already read it
    request.body.rewind
    # The raw text of the body is required for webhook signature verification
    @payload_raw = request.body.read
    begin
      @payload = JSON.parse @payload_raw
    rescue => e
      fail  "Invalid JSON (#{e}): #{@payload_raw}"
    end
  end

  # Instantiate an Octokit client authenticated as a GitHub App.
  # GitHub App authentication requires that you construct a
  # JWT (https://jwt.io/introduction/) signed with the app's private key,
  # so GitHub can be sure that it came from the app and wasn't alterered by
  # a malicious third party.
  def authenticate_app
    payload = {
        # The time that this JWT was issued, _i.e._ now.
        iat: Time.now.to_i,

        # JWT expiration time (10 minute maximum)
        exp: Time.now.to_i + (10 * 60),

        # Your GitHub App's identifier number
        iss: APP_IDENTIFIER
    }

    # Cryptographically sign the JWT.
    jwt = JWT.encode(payload, PRIVATE_KEY, 'RS256')

    # Create the Octokit client, using the JWT as the auth token.
    @app_client ||= Octokit::Client.new(bearer_token: jwt)
  end

  # Instantiate an Octokit client, authenticated as an installation of a
  # GitHub App, to run API operations.
  def authenticate_installation(payload)
    @installation_id = payload['installation']['id']
    @installation_token = @app_client.create_app_installation_access_token(@installation_id)[:token]
    @installation_client = Octokit::Client.new(bearer_token: @installation_token)
  end

  # Check X-Hub-Signature to confirm that this webhook was generated by
  # GitHub, and not a malicious third party.
  #
  # GitHub uses the WEBHOOK_SECRET, registered to the GitHub App, to
  # create the hash signature sent in the `X-HUB-Signature` header of each
  # webhook. This code computes the expected hash signature and compares it to
  # the signature sent in the `X-HUB-Signature` header. If they don't match,
  # this request is an attack, and you should reject it. GitHub uses the HMAC
  # hexdigest to compute the signature. The `X-HUB-Signature` looks something
  # like this: "sha1=123456".
  # See https://developer.github.com/webhooks/securing/ for details.
  def verify_webhook_signature
    their_signature_header = request.env['HTTP_X_HUB_SIGNATURE'] || 'sha1='
    method, their_digest = their_signature_header.split('=')
    our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, @payload_raw)
    halt 401 unless their_digest == our_digest

    # The X-GITHUB-EVENT header provides the name of the event.
    # The action value indicates the which action triggered the event.
    logger.debug "---- received event #{request.env['HTTP_X_GITHUB_EVENT']}"
    logger.debug "----    action #{@payload['action']}" unless @payload['action'].nil?
  end
end