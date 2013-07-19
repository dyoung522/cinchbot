require 'optparse'
require 'ostruct'

class OptParse
    #
    # Return a structure describing the options.
    #
    def self.parse(args)
        # The options specified on the command line will be collected in *options*.
        # We set default values here.
        options = OpenStruct.new
        options.conf_file = nil
        options.verbose = false
        options.pretend = false

        opt_parser = OptionParser.new do |opts|
            opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

            opts.separator ""
            opts.separator "Specific options:"

            # Mandatory argument.
            opts.on('-c', '--config CONFIG', 'Read our configuration items from CONFIG') do |conf|
                options.conf_file = conf if File.exists?(conf)
            end

            # Boolean switch.
            opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
                options.verbose = v
            end

            opts.on_tail('--pretend', "Run the program but don't actually start the bots") do
                options.pretend = true
            end

            opts.separator ""
            opts.separator "Common options:"

            # No argument, shows at tail.  This will print an options summary.
            # Try it and see!
            opts.on_tail("-h", "--help", "Show this message") do
                puts version + "\n"
                puts opts
                exit
            end

            # Another typical switch to print the version.
            opts.on_tail("--version", "Show version") do
                puts version
                exit
            end
        end

        opt_parser.parse!(args)

        # Set default config file if not provided above
        options.conf_file ||= "#{File.basename($PROGRAM_NAME).gsub('.rb', '.yml')}" 

        options
    end  # parse()

    def self.version
        sprintf "%s - %s by %s\n", $PROGRAM, $VERSION, $AUTHOR
    end

end  # class OptParse

