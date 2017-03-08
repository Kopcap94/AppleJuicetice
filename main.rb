require 'discordrb'
require 'json'
require_relative './commands'
require_relative './vk'
require_relative './wiki'

module DiscordBot
	class Discord
		include Discordrb
		include Commands
		include VK
		include Wiki

		attr_accessor :bot, :channels, :config

		def initialize
			unless File.exists?( 'cfg.json' )
				File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate({ 'token' => '', 'id' => '', 'prefix' => '!', 'groups' => {} }) ) }
				puts "Создан новый конфиг, заполните его."
			end

			@config = JSON.parse( File.read( 'cfg.json' ) )
			@bot = Discordrb::Commands::CommandBot.new token: @config[ 'token' ], client_id: @config[ 'id' ], prefix: @config[ 'prefix' ]
			@channels = {}

			@vk = VK::VK.new( self )
			@com = Commands::Commands.new( self )
			@wiki = Wiki::Wiki.new( self )
		end

		def start
			@bot.ready do |e|
				@bot.servers.each do |k, v|
					v.roles.each {| arr, i | @bot.set_role_permission( arr.id, [ 'Администратор', 'Модератор' ].index( arr.name ).nil? ? 1 : 2 ) }
					v.channels.each {| arr | @channels[ arr.name ] = arr.id }
				end

				@vk.start_group_gathering
				@wiki.start_check_recent_changes
			end

			events_block
			command_block
			permissions_block

			@bot.run
		end

		def save_config
			File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @config ) ) }
		end

		def events_block
			@bot.member_join  do | e | @com.new_user_join( e ) end
			@bot.member_leave do | e | @com.user_left( e )     end
			@bot.mention      do | e | @com.mentioned( e )     end
		end

		def command_block
			@bot.command( 
				:help,
				description: "Выводит справку о командах бота в ЛС участника.",
				usage: "Не требует параметров." 
			) do | e | @com.help( e ) end

			@bot.command(
				:info,
				description: "Выводит информацию о боте.",
				usage: "Не требует параметров." 
			) do | e | @com.bot_info( e ) end

			@bot.command(
				:avatar,
				min_args: 1,
				description: "Выводит ссылку на аватар участника.",
				usage: "Требуется упомянуть цель: !avatar @kopcap"
			) do | e, u | @com.avatar( e, u ) end
		end

		def permissions_block
			@bot.command(
				:uploads,
				permission_level: 2,
				description: "Включает или выключает отображение логов загрузки в свежих правках.",
				usage: "Не требует параметров."
			) do | e | @com.switch_uploads( e ) end

			@bot.command(
				:add_group,
				permission_level: 2,
				min_args: 1,
				description: "Добавляет ID группы VK в список патрулируемых.",
				usage: "Требует ID группы: !add_group -2000"
			) do | e, g | @com.add_group( e, g ) end

			@bot.command(
				:nuke,
				permission_level: 2,
				min_args: 1,
				description: "Удаляет указанное кол-во сообщений. Число сообщений для удаления должно быть в диапазоне от 2 до 100.",
				usage: "Требует указать число в диапазоне от 2 до 100: !nuke 10"
			) do | e, i | @com.nuke( e, i ) end

			@bot.command(
				:set_time, 
				permission_level: 2,
				min_args: 3,
				description: "Устанавливает задержку между проверками свежих правок [ rc ] или групп VK [ vk ].",
				usage: "Требует 2 параметра - тип проверки [ vk, rc ] и задержку в секундах: !set_time vk 10"
			) do | e, t, i | @com.set_time( e, t, i ) end
		end
	end
end