require 'httparty'
require 'json'

module DiscordBot
	module Wiki
	  class Wiki
		include HTTParty

		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config
		end

		def commands
			@bot.command(
				:uploads,
				permission_level: 2,
				description: "Включает или выключает отображение логов загрузки в свежих правках.",
				usage: "Не требует параметров."
			) do | e | switch_uploads( e ) end
		end

		def start_check_recent_changes
			@config[ 'wikies' ].each do | w, r |
				init_cheсking( w, r )
			end

			sleep 30
			start_check_recent_changes
		end
		
		def init_cheсking( w, d )
			Thread.new {
				begin
					get_data_from_api( w, d )
				rescue => err
					puts "#{ err }: #{ err.backtrace }"
				end
			}
		end

		def get_data_from_api( w, data )
			d =  JSON.parse(
				HTTParty.get(
					"http://#{ w }.wikia.com/api.php?action=query&list=recentchanges&rclimit=50&rcprop=user|title|timestamp|ids|comment|sizes&format=json",
					:verify => false
				).body,
				:symbolize_names => true
			)[ :query ][ :recentchanges ]

			rcid = data
			show_uploads = @config[ 'show_uploads' ]
			last_rcid = d[ 0 ][ :rcid ]

			if rcid == 0 then
				@config[ 'wikies' ][ w ] = last_rcid
				@client.save_config
				return
			end

			if last_rcid <= rcid then
				return
			end

			d.reverse.each do | obj |
				if obj[ :rcid ] <= rcid then
					next
				elsif obj[ :type ] == 'log' and obj[ :ns ] == 6 and !show_uploads then
					next
				end

				emb = Discordrb::Webhooks::Embed.new
				emb.color = "#507299"

				case obj[ :type ]
				when "log"
					type = "Лог :pencil:"
				when "edit"
					type = "Изменение страницы :pencil2:"
				when "new"
					type = "Новая страница :paintbrush:"
				else
					type = "Неизвестный тип изменения :heavy_multiplication_x:"
				end

				title = obj[ :title ]
				if [ 110, 111, 1200, 1201, 1202, 2001, 2002 ].index( obj[ :ns ] ) then title = "Тема на форуме или стене обсуждения" end

				emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: title, url: "http://ru.mlp.wikia.com/index.php?title=#{ obj[ :title ].gsub( /\s/, "_" ) }" )
				emb.title = "http://ru.mlp.wikia.com/index.php?diff=#{ obj[ :revid ] }"
				emb.add_field( name: "Участник", value: obj[ :user ], inline: true )

				if obj[ :ns ] != 6 then
					emb.add_field( name: "Изменения:", value: "#{ obj[ :newlen ] - obj[ :oldlen ] } байт", inline: true )
					if obj[ :comment ] != "" then
						emb.add_field( name: "Описание правки", value: "#{ obj[ :comment ] }" )
					end
				end

				@bot.send_message( @channels[ 285482504817868800 ][ 'recentchanges' ], '', false, emb )
				sleep 1
			end

			@config[ 'wikies' ][ w ] = last_rcid
			@client.save_config
		end

		def switch_uploads( e )
			@config[ 'show_uploads' ] = !@config[ 'show_uploads' ]
			@client.save_config

			e.respond "Отображение логов о загрузке изображений: #{ @config[ 'show_uploads' ] ? "включено" : "выключено" }."
		end
	  end
	end
end