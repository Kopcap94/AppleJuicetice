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
					v.channels.each {| arr | @channels[ arr.name ] = arr.id }
				end

				@vk.start_group_gathering
				@wiki.start_check_recent_changes
			end

			command_block

			@bot.run
		end

		def save_config
			File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @config ) ) }
		end

		def command_block
			@bot.member_join		do | e | 	@com.new_user_join( e )		end
			@bot.member_leave		do | e | 	@com.user_left( e ) 		end
			@bot.mention			do | e | 	@com.mentioned( e ) 		end
			@bot.command :help		do | e | 	@com.help( e ) 				end
			@bot.command :add_group	do | e, g | @com.add_group( e, g )		end
			@bot.command :avatar	do | e, u | @com.avatar( e, u )			end
			@bot.command :uploads	do | e |	@com.switch_uploads( e )	end
		end
	end
end