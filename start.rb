require_relative './main'
require_relative './commands'
require_relative './plugins/wiki'
require_relative './plugins/games'
require_relative './plugins/mafia'
require_relative './plugins/tcp'
require_relative './plugins/vk'

_this = DiscordBot::Main.new
_this.start
