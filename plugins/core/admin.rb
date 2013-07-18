class Admin
  include Cinch::Plugin
  include Cinch::Extensions::Authentication

  match /quit\s*(.*)/, :method => :bot_quit

  def bot_quit( m, msg = nil )
    return unless authenticated?( m, :admins )
    m.bot.quit( msg )
  end
end
