require 'bundler/setup'

require 'octokit'
require "base64"
require 'json'
require 'logger' 
require 'ostruct'
require 'test/unit'
require "test/unit/rr"

require './server.rb'
require './application_helper.rb'

ENV["RAILS_ENV"] = "test"

class DummyClass
    include ApplicationHelper
end

# Run 'ruby unittests.rb'
class TestAdd < Test::Unit::TestCase
    def test_match

      	logger = Logger.new(STDOUT)

    	ghApp = GHAapp.new()
    
        content = File.read("test_mapping.json").chomp
        json = JSON.parse(content)
        logger.debug("json: ")
        logger.debug(json)

        # Represents the files changed in a PR
        filenames = [ 'gutenberg/packages/block-editor/src/components/media-upload/index.native.js', 
        	'WordPress/Classes/ViewRelated/Gutenberg/Processors/GutenbergGalleryUploadProcessor.swift', 
        	'WordPress/Classes/ViewRelated/Gutenberg/Processors/GutenbergImgUploadProcessor.swift', 
        	'WordPress/Classes/ViewRelated/Gutenberg/Processors/GutenbergVideoUploadProcessor.swift' ]

        files = []
        filenames.each { |filename| puts 
        	newfile = OpenStruct.new
        	newfile.filename = filename
        	files << newfile
        }

        test_suites = ghApp.helpers.find_matched_testcase_files(files, json, logger)
        logger.debug("matched suites: ")
        logger.debug(test_suites)

        assert_equal test_suites.length(), 7
		assert test_suites.include?("gutenberg/image-upload.md")
		assert test_suites.include?("gutenberg/video-upload.md")
		assert test_suites.include?("gutenberg/media-text-upload.md")
		assert test_suites.include?("gutenberg/gallery-upload-processor.md")
		assert test_suites.include?("gutenberg/multi-block-media-upload.md")
		assert test_suites.include?("gutenberg/img-upload-processor.md")
		assert test_suites.include?("gutenberg/video-upload-processor.md")
    end

    def test_default_config
    	ghApp = GHAapp.new()
        default_config = ghApp.helpers.default_config()
        expected_config = {
            tests_dir: 'test-suites/',
            mapping_file: 'config/mapping.json',
            tests_repo: 'wordpress-mobile/test-cases',
            comment_footer: "\n\nIf you think that suggestions should be improved please edit the configuration file [here](https://github.com/wordpress-mobile/test-cases/blob/master/config/mapping.json). You can also modify/add [test-suites](https://github.com/wordpress-mobile/test-cases/tree/master/test-suites) to be used in the [configuration](https://github.com/wordpress-mobile/test-cases/blob/master/config/mapping.json).\n\n If you are a beginner in mobile platforms follow [build instructions](https://github.com/wordpress-mobile/test-cases/blob/master/README.md#build-instructions).",
          }
        assert_equal(expected_config, default_config)
    end

    def test_fetch_repo_config
        ghApp = DummyClass.new()
      	logger = Logger.new(STDOUT)

        expected_config = {
            tests_dir: 'tests_dir',
            mapping_file: 'mapping_file',
            tests_repo: 'tests_repo',
            comment_footer: 'comment_footer'
        }
        content = Base64.encode64(expected_config.to_json)

        any_instance_of(Octokit::Client) do |klass|
            stub(klass).contents { { content: content } }
        end

        config = ghApp.fetch_config('test-repo', logger)
        assert_equal(expected_config, config)
    end

    def test_fetch_default_config
        ghApp = DummyClass.new()
      	logger = Logger.new(STDOUT)

        default_config = ghApp.default_config()

        any_instance_of(Octokit::Client) do |klass|
            stub(klass).contents { throw Exception.new() }
        end

        config = ghApp.fetch_config('test-repo', logger)
        assert_equal(default_config, config)
    end
end

