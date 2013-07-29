# Add camelcase method to Strings
class String
    def camelcase
        return self if self !~ /_/ && self =~ /[A-Z]+.*/
        split('_').map{|e| e.capitalize}.join
    end
end

# Class to load and process our config file
module CinchBot
    class Config
        Network = Struct.new( :server, :port, :ssl, :password, :nick, :nicks,
                              :realname, :user, :messages_per_second, :server_queue_size,
                              :strictness, :message_split_start, :message_split_end,
                              :max_messages, :plugins, :channels, :encoding, :reconnect, :max_reconnect_delay,
                              :local_host, :timeouts, :ping_interval, :delay_joins, :dcc, :shared, :sasl )

        # Class to handle plugin files
        class Plugin
            def initialize( file )
              @plugin = file
            end

            def classname
                Object.const_get self.basename.gsub(/.rb$/, '').camelcase
            end

            def basename
                File::basename @plugin
            end
        end

        # Container attributes
        attr_reader :defaults, :networks

        def initialize( config_file )
            return unless config_file

            @defaults = Hash.new
            @networks = Hash.new
            @plugins  = {
                core: [],
                extra: []
            }

            begin
                puts "Reading config from #{config_file}" if $options.verbose
                @config = YAML.load_file( config_file )

                # Populate @defaults
                @config['networks'].delete('defaults').each { |key, value| @defaults[key] = value }

                # Load networks hash
                @config['networks'].each { |name, details| @networks[name] = Network.new( details ) }

            # Syntax Error
            rescue Psych::SyntaxError
                puts "Error:  There was a problem reading #{config_file}, please check it and try again"
                exit

            # No File
            rescue Errno::ENOENT
                puts "Could not find #{config_file}, please create this file first."
                exit
            end

            # Main Bot Directory (all future paths will be relative to this, unless specified otherwise in the config)
            dir_main = ( File.expand_path(@config['dir_main']) || '.' )

            begin
                Dir.chdir dir_main
            rescue
                puts "WARNING: #{dir_main} does not exist; using current directory -- this may fail."
                dir_main = File.expand_path('.')
            end

            # Collect and enable plugins
            # Load core plugins
            plugins_core = @config['plugins']['core'] || "#{dir_main}/plugins/core"

            raise "Required directory, #{plugins_core}, cannot be found.  Please check your plugins_core configuration item and try again." unless Dir.exists?(plugins_core)

            puts "Loading core plugins from #{plugins_core}" if $options.debug

            Dir.glob("#{plugins_core}/*.rb").each do |file| 
                require_relative "#{dir_main}/#{file}"
                @plugins[:core] << Plugin.new(file)
            end

            begin
                # Load optional extra plugins
                plugins_extra = @config['plugins_extra'] || 'plugins/enabled'

                puts "Loading extra plugins from #{plugins_extra}" if $options.debug
      
                # Find the files in the plugin_dir and load them
                Dir.glob("#{plugins_extra}/*.rb").each do |file| 
                    require_relative "#{dir_main}/#{file}"
                    @plugins[:extra] << Plugin.new(file)
                end

            rescue Errno::ENOENT
                puts 'Whoops, looks like the plugins directory specified in the config (plugins_extra) is invalid.'
            end

            puts "#{@plugins[:extra].count > 0 ? @plugins[:extra].count : 'no'} plugins loaded." if $options.debug

        end

        ##
        ## Methods
        ##
        def plugins
            classes = Array.new
            @plugins.keys.each { |key| @plugins[key].map { |f| classes << f.classname } }
            return classes
        end
    end # Class
end # Module