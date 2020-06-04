require 'bundler/setup'

require 'test/unit'
require './server.rb'
require 'octokit'
require "base64"
require 'json'
require 'logger' 
require 'ostruct'


ENV["RAILS_ENV"] = "test"

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
end

