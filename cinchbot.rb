#!/usr/bin/env ruby

# Global variables
$AUTHOR  = 'Donovan C. Young'
$VERSION = 'v1.3'
$PROGRAM = "#{File.basename($PROGRAM_NAME).gsub('.rb', '')}" 

LIB = File.expand_path(File.dirname(__FILE__)) + '/lib'

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

    # Skip this network if it's been disabled.
    next if network.disabled

    puts "Building config for #{name}" if $options.debug

    Thread.abort_on_exception = true    # Show exceptions as they happen
    thread = Thread.new do
        bot = Cinch::Bot.new do
            configure do |c|
                # Authentication configuration
                c.authentication          = Cinch::Configuration::Authentication.new
                c.authentication.strategy = :list
                c.authentication.level    = [ :owners, :admins, :users ]

                # Server configuration
                network.each_pair do |key, value|
                    case key
                    when :sasl
                        c.sasl.username = value['username']
                        c.sasl.password = value['password']
                    when :auth
                        c.authentication.owners = ( value['owners'] || [] )
                        c.authentication.admins = ( value['admins'] || [] )
                        c.authentication.users  = ( value['users']  || [] )
                    else
                        c.send( "#{key}=".to_sym, value ) unless value.nil?
                    end
                end

                # Plugin configuration
                c.plugins.plugins = $config.plugins
            end
        end

        # Validate authentication owner
        if bot.config.authentication.owners.empty?
            puts "FATAL:  No owners have been configured on #{name}, you need at least one. Not starting bot."
            next
        end

        # Add file logging when requested.
        bot.loggers << Cinch::Logger::FormattedLogger.new(network.server['log_file']) if network.server['log_file']

        # Set Default logging level
        bot.loggers.level = $options.debug ? :debug : :info

        # close down STDERR unless verbose has been specified
        bot.loggers.first.level = :warn unless $options.verbose

        print "Starting connection to #{bot.config.server}... " if $options.verbose
        unless $options.pretend
            bot.start
            puts "started." if $options.verbose
        else
            puts "(pretending)" if $options.verbose
        end

    end

    threads.join_nowait( thread )
end

# Wait for all threads to complete
sleep while threads.all_waits 

puts "All connections dropped.  That's all, folks." if $options.verbose and !$options.pretend
