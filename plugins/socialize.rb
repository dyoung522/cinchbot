class Socialize
  include Cinch::Plugin
  include Cinch::Extensions::Authentication

  set :plugin_name, 'socialize'
  set :help, <<-USAGE.gsub(/^\s*/, '')
      Listens to the channel for the bot's nick, response appropriately when heard.
      Also includes social bot commands:
      - !say [#channel] <message>       : Makes the bot say <message> in #channel or the current channel
  USAGE

  class Reply

    @@responses = {

      :thank => [
          "You're welcome, %NICK%",
          "da nada",
          "Hey, %NICK%, no problem!",
          "just doing my job",
          "who loves ya, %NICK%?",
          "you bet!"
      ],

      :hello => [
          "howdy, %NICK%",
          "hello, %NICK%",
          "hola, %NICK%",
          "hi %NICK%!"
      ],

      :insult => [
          "your mother, %NICK%",
          "hey %NICK%!  Go die in a fire.",
          "really %NICK%?  You're trying to insult a bot?",
          "your mother was a hamster and your father smelt of elderberries",
          "fuck off and die, %NICK%",
          "I'm not sure that's possible, %NICK%, but you can try if you like."
      ],

      :other => [
          "If you say so, %NICK%",
          "okay",
          "yes %NICK%?",
          "right back atcha %NICK%",
          "I didn't catch that %NICK%"
      ]
    }

    def initialize ( type = :thank, percent = 100 )
      @responses = @@responses[type]
      @percent = percent.to_i
    end

    def respond_to ( nick = 'human' )
      puts "There's a #{@percent}% chance of a response."
      return '' unless rand(100) < @percent
      return "I have nothing to say, #{nick}" unless @responses
      @responses[rand(@responses.length)].gsub(/%NICK%/, nick)
    end

    def percent( percent )
      percent = 0   if percent.to_i < 0
      percent = 100 if percent.to_i > 100
      @percent = percent.to_i
      self
    end

  end # class Reply


  listen_to :message
  match /say\s+(?:(#\S+)\s+)?(.*)/, :method => :bot_say

  def listen(m)
    return if m.message =~ /^#{bot.config.plugins.prefix}/
    return if m.user.nil? || m.user.authname.nil? # only respond to authenticated users

    if m.message =~ /#{bot.nick}/i
      case m.message
        when /thank|gracias/i                       then m.reply Reply.new(:thank,  80).respond_to(m.user.nick)
        when /(hello|hi|howdy|eve|morn|noon|hola)/i then m.reply Reply.new(:hello,  90).percent(90).respond_to(m.user.nick)
        when /(fuck|shit|cunt|suck|cock|dick|ass)/i then m.reply Reply.new(:insult, 10).percent(10).respond_to(m.user.nick)
        else m.reply Reply.new(:other).respond_to(m.user.nick)
      end
    end
  end

  def bot_say( m, channel, message )
    return unless authenticated?(m)
    channel ||= m.channel
    if channel
      Channel(channel).send message
    else
      m.reply "I'm sorry, but you didn't tell me which channel."
    end
  end

end #Class
