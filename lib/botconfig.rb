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
        Network = Struct.new( :server, :port, :ssl, :password, :nick, :nicks, :realname, :user, 
                              :messages_per_second, :server_queue_size, :strictness, :message_split_start, 
                              :message_split_end, :max_messages, :plugins, :channels, :encoding, :reconnect, 
                              :max_reconnect_delay, :local_host, :timeouts, :ping_interval, :delay_joins, :dcc, 
                              :shared, :sasl, :auth, :auth_file, :log_file, :disabled )

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
        attr_reader :defaults, :networks, :config_file

        def __initvars__
            @config         = nil
            @networks       = Hash.new
            @plugins        = { :core => [], :extra => [] }
        end
        private :__initvars__

        def initialize( config_file = nil )
            __initvars__

            # Autoload the config
            load config_file
        end

        def load( config_file = nil )
            # Reset vars, makes for clean reloads
            __initvars__

            @config_file = config_file if config_file

            # Bomb out if we get here without a config_file being set
            raise RuntimeError "A config_file has not been provided." unless @config_file

            begin
                puts "Reading config from #{@config_file}" if $options.verbose
                @config = YAML.load_file( @config_file )

            # Syntax Error
            rescue Psych::SyntaxError
                puts "Error:  There was a syntax error while reading from #{@config_file}, please check it and try again"
                exit 1

            # No File
            rescue Errno::ENOENT
                puts "Could not find #{@config_file}, please create this file first."
                exit 1
            end

            # Populate @defaults
            defaults = @config['networks'].delete('defaults')

            # Load networks hash
            @config['networks'].each do |name, details| 
                @networks[name] = Network.new

                # Set and open our log file
                if details.has_key?('log_file')
                    begin
                        @networks[name].log_file = File.open(details['log_file'], 'a')
                    rescue Errno::ENOENT
                        puts "FATAL: Could not open #{details['log_file']}"
                        exit
                    end
                end

                # Read in our Authentication file
                if details.has_key?('auth_file') && File.exists?(details['auth_file'])
                    @networks[name].auth = YAML.load_file( details['auth_file'] )
                end

                # Build the @network hash
                details.each  { |key, value| @networks[name].send( "#{key}=".to_sym, value ) }

                # Apply defaults
                defaults.each do |key, value| 
                    @networks[name].send( "#{key}=".to_sym, value ) unless @networks[name].send( key )
                end
            end

            # Main Bot Directory (all future paths will be relative to this, unless specified otherwise in the config)
            dir_main = File.expand_path(@config['dir_main'])

            begin
                Dir.chdir dir_main
            rescue
                puts "WARNING: #{dir_main} does not exist; using current directory -- this may cause failures later."
                dir_main = File.expand_path('.')
            end

            # Collect and enable plugins
            # Load core plugins
            plugins_core = @config['plugins']['core'] || "#{dir_main}/plugins/core"

            raise "Required directory, #{plugins_core}, cannot be found.  Please check your plugins_core configuration item and try again." unless Dir.exists?(plugins_core)

            puts "Loading core plugins from #{plugins_core}" if $options.verbose

            Dir.glob("#{plugins_core}/*.rb").each do |file| 
                require_relative "#{dir_main}/#{file}"
                @plugins[:core] << Plugin.new(file)
                puts "Loading #{file}" if $options.debug
            end

            begin
                # Load optional extra plugins
                plugins_extra = @config['plugins_extra'] || 'plugins/enabled'

                puts "Loading extra plugins from #{plugins_extra}" if $options.verbose
      
                # Find the files in the plugin_dir and load them
                Dir.glob("#{plugins_extra}/*.rb").each do |file| 
                    require_relative "#{dir_main}/#{file}"
                    @plugins[:extra] << Plugin.new(file)
                    puts "Loading #{file}" if $options.debug
                end

            rescue Errno::ENOENT
                puts 'Whoops, looks like the plugins directory specified in the config (plugins_extra) is invalid.'
            end

            [:core, :extra].each do |sym|
                puts "#{@plugins[sym].count > 0 ? @plugins[sym].count : 'no'} #{sym.to_s} plugins loaded." if $options.verbose
            end

        end

        ##
        ## Methods
        ##
        def plugins
            classes = Array.new
            @plugins.keys.each { |key| @plugins[key].map { |f| classes << f.classname } }
            classes
        end

        def path( item )
            case item.to_s
                when /main/     then @config['dir_main']
                when /core/     then @config['plugins']['core']
                when /plugins?/ then @config['plugins']['extra']
                else nil
            end
        end

    end # Class
end # Module