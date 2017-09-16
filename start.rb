require_relative './main'
require_relative './commands'
require_relative './plugins/vk'
require_relative './plugins/wiki'
require_relative './plugins/games'
require_relative './plugins/mafia'
require_relative './plugins/voice'

_this = DiscordBot::Main.new
_this.start