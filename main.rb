require 'discordrb'
require 'json'
require_relative './commands'
require_relative './vk'
require_relative './wiki'
require_relative './games'

module DiscordBot
	class Discord
		include Discordrb
		include Commands
		include VK
		include Wiki
		include Games

		attr_accessor :bot, :channels, :config

		def initialize
			unless File.exists?( 'cfg.json' )
				File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate({ 'token' => '', 'id' => '', 'prefix' => '!', 'groups' => {} }) ) }
				puts "Создан новый конфиг, заполните его."
			end

			@config = JSON.parse( File.read( 'cfg.json' ) )
			@bot = Discordrb::Commands::CommandBot.new token: @config[ 'token' ], client_id: @config[ 'id' ], prefix: @config[ 'prefix' ]
			@channels = {}
			@cfg_mutex = Mutex.new

			@vk = VK::VK.new( self )
			@com = Commands::Commands.new( self )
			@wiki = Wiki::Wiki.new( self )
			@games = Games::Games.new( self )
		end

		def start
			@bot.ready do |e|
				@bot.servers.each do |k, v|
					@channels[ k ] = {}
					v.roles.each {| arr, i | @bot.set_role_permission( arr.id, [ 'Администратор', 'Модератор' ].index( arr.name ).nil? ? 1 : 2 ) }
					v.channels.each {| arr | @channels[ k ][ arr.name ] = arr.id }
				end

				@games.init_mafia
				@vk.start_group_gathering
				@wiki.start_check_recent_changes
			end

			@bot.member_join  do | e |
				g = e.server.roles.find { |r| r.name == "Новички" }
				e.user.add_role( g )
				e.server.general_channel.send_message "Добро пожаловать на сервер, <@#{ e.user.id }>. Пожалуйста, предоставьте ссылку на свой профиль в Фэндоме, чтобы администраторы могли добавить вас в группу."
			end

			@bot.member_leave do | e |
				e.server.general_channel.send_message "#{ e.user.name } покинул сервер."
			end

			@bot.mention do | e | 
				e.respond "<@#{ e.user.id }>, если вам требуется список команд, используйте команду !help."
			end

			@bot.command :eval do | e, *c |
				break unless e.user.id == @config[ 'owner' ]

				begin
					eval c.join(' ')
				rescue
					'Ошибка в коде'
				end
			end

			@games.commands
			@vk.commands
			@com.commands
			@wiki.commands
			permissions_block

			@bot.run
		end

		def save_config
			@cfg_mutex.synchronize do
				File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @config ) ) }
			end
		end

		def permissions_block
			@bot.command(
				:nuke,
				permission_level: 2,
				min_args: 1,
				description: "Удаляет указанное кол-во сообщений. Число сообщений для удаления должно быть в диапазоне от 2 до 100.",
				usage: "Требует указать число в диапазоне от 2 до 100: !nuke 10"
			) do | e, i | @com.nuke( e, i ) end
		end
	end
end