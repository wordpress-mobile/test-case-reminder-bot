# Gutenberg Tests - Reminder Bot

A GitHub bot that drops a comment into the PR about what to test when specific files change in gutenberg repo. Test cases and configurations live in [gutenberg-tests]([https://github.com/wordpress-mobile/gutenberg-tests](https://github.com/wordpress-mobile/gutenberg-tests)) repo. This is just the server implementation.

## Install

To run the code, make sure you have [Bundler](http://gembundler.com/) installed; then enter `bundle install` on the command line.

## Set environment variables

1. Create a copy of the `.env-example` file called `.env`.
2. Add your GitHub App's private key, app ID, and webhook secret to the `.env` file.

## Run the server

1. Run `ruby server.rb` on the command line.
2. View the default Sinatra app at `localhost:3000`.

## Develop

[This guide](https://developer.github.com/apps/quickstart-guides/setting-up-your-development-environment/) will walk through the steps needed to configure a GitHub App and run it on a server.

After completing the necessary steps in the guide you can use this command in this directory to run the smee client(replacing `https://smee.io/4OcZnobezZzAyaw` with your own domain):

> smee --url https://smee.io/4OcZnobezZzAyaw --path /event_handler --port 3000

## Reload Changes

If you want server to reload automatically as you save the file  you can start the server as below instead of using `ruby server.rb`:

> gem install rerun
> rerun 'ruby server.rb'

