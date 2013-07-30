#!/usr/bin/env ruby

# Global variables
$AUTHOR  = 'Donovan C. Young'
$VERSION = 'v1.3'
$PROGRAM = "#{File.basename($PROGRAM_NAME).gsub('.rb', '')}" 

LIB = File.expand_path(File.dirname(__FILE__)) + '/lib'

require 'rubygems'
require 'bundler/setup'
require 'pp'
require 'yaml'
require 'thwait'
require 'sequel'
require 'cinch'
require 'cinch/extensions/authentication'

require "#{LIB}/optparse"
require "#{LIB}/botconfig"

# Parse command line arguments
$options = OptParse.parse(ARGV)

# Load and process the config file
$config  = CinchBot::Config.new( $options.conf_file ) || exit

# Create a threadswait container
threads = ThreadsWait.new

# cycle through the configured networks and start our bot(s)
$config.networks.each do |name, network|
    Thread.abort_on_exception = true    # Show exceptions as they happen
    thread = Thread.new do
        bot = Cinch::Bot.new do
            configure do |c|
                # Authentication configuration
                c.authentication          = Cinch::Configuration::Authentication.new
                c.authentication.level    = :users
                c.authentication.strategy = :list
                c.authentication.level    = [:owner, :admins, :users]

                # Plugin configuration
                c.plugins.plugins = $config.plugins

                # Set defaults (may be overwritten below)
                $config.defaults.each { |key, value| c.send( "#{key}=".to_sym, value ) }

                # Server configuration
                network.server.each do |key, value| 
                    case key
                    when /^sasl$/i
                        c.sasl.username = value['username']
                        c.sasl.password = value['password']
                    when /^auth$/i
                        c.authentication.owner    = [ value['owner'] ]
                        c.authentication.admins   = c.authentication.owner  + ( value['admins'] || [] )
                        c.authentication.users    = c.authentication.admins + ( value['users']  || [] )
                    else
                        c.send( "#{key}=".to_sym, value )
                    end
                end
            end
        end

        # Add file logging when requested.
        bot.loggers << Cinch::Logger::FormattedLogger.new($options.log_file) if $options.log_file

        # Set Default logging level
        bot.loggers.level = $options.debug ? :debug : :info

        # close down STDERR unless verbose has been specified
        bot.loggers.first.level = :warn unless $options.verbose

        unless $options.pretend
            puts "Starting connection to #{bot.config.server}" if $options.verbose
            bot.start
        end
    end

    threads.join_nowait( thread )
end

# Wait for all threads to complete
sleep while threads.all_waits 

puts "All connections dropped.  That's all, folks." if $options.verbose and !$options.pretend
