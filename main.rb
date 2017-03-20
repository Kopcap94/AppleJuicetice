require 'discordrb'
require 'json'
require 'httparty'

module DiscordBot
	class Main
		attr_accessor :bot, :channels, :config

		def initialize
			unless File.exists?( 'cfg.json' )
				File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate({ 
					'token' => '', 
					'id' => '',
					'prefix' => '!', 
					'owner' => 0,
					'wikies' => {},
					'show_uploads' => false,
					'groups' => {}
				}))}
				puts "Создан новый конфиг, заполните его."
			end

			@config = JSON.parse( File.read( 'cfg.json' ) )
			@bot = Discordrb::Commands::CommandBot.new token: @config[ 'token' ], client_id: @config[ 'id' ], prefix: @config[ 'prefix' ], help_command: false
			@channels = {}
			@cfg_mutex = Mutex.new
		end

		def start
			@bot.ready do | e |
				@bot.update_status( 'Discord Ruby', '!help', nil )

				@bot.servers.each do |k, v|
					@channels[ k ] = {}
					v.roles.each do | arr, i |
						perm = arr.permissions
						@bot.set_role_permission( arr.id, ( perm.kick_members or perm.ban_members or perm.administrator or perm.manage_server ) ? 2 : 1 )
					end
					v.channels.each {| arr | @channels[ k ][ arr.name ] = arr.id }
				end

				register_modules
			end

			@bot.channel_create do | e |
				break unless !e.channel.pm?
				@channels[ e.server.id ][ e.name ] = e.channel.id
			end

			@bot.channel_delete do | e |
				@channels[ e.server.id ].delete( e.name )
			end

			@bot.member_join do | e |
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

			@bot.run
		end

		def register_modules
			DiscordBot.constants.select do | c |
				if DiscordBot.const_get( c ).is_a? Class then
					if c.to_s == "Main" then
						next
					end

					m = DiscordBot.const_get( c ).new( self )

					if DiscordBot.const_get( c ).method_defined? "commands" then
						m.commands
					end
				end
			end
		end

		def save_config
			@cfg_mutex.synchronize do
				File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @config ) ) }
			end
		end
	end
end