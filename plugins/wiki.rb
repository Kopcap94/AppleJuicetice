require 'httparty'
require 'json'

module DiscordBot
	class Wiki
		include HTTParty

		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config

			for_init
		end

		def commands
			@bot.command(
				:uploads,
				permission_level: 2,
				description: "Включает или выключает отображение логов загрузки в свежих правках.",
				usage: "Не требует параметров."
			) do | e | switch_uploads( e ) end

			@bot.command(
				:add_wiki,
				permission_level: 2,
				min_args: 1,
				description: "Добавляет вики в список патрулируемых и выводит правки в канал #recentchanges.",
				usage: "!add_wiki ru.mlp"
			) do | e, w | add_wiki( e, w ) end
		end

		def for_init
			Thread.new {
				@config[ 'wikies' ].each do | w, r |
					init_cheсking( w, r )
				end
			}
		end
		
		def init_cheсking( w, d )
			Thread.new {
				begin
					get_data_from_api( w, d )
				rescue => err
					puts "#{ err }: #{ err.backtrace }"
				end

				sleep 60
				init_cheсking( w, @config[ 'wikies' ][ w ] )
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

			rcid = data[ 'rcid' ]
			show_uploads = @config[ 'show_uploads' ]
			last_rcid = d[ 0 ][ :rcid ]

			if rcid == 0 then
				@config[ 'wikies' ][ w ][ 'rcid' ] = last_rcid
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

				title = "[ #{ w } ] #{ obj[ :title ] }"
				if [ 110, 111, 1200, 1201, 1202, 2001, 2002 ].index( obj[ :ns ] ) then title = "[ #{ w } ] Тема на форуме или стене обсуждения" end

				emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: title, url: "http://#{ w }.wikia.com/index.php?title=#{ obj[ :title ].gsub( /\s/, "_" ) }" )
				emb.title = "http://#{ w }.wikia.com/index.php?diff=#{ obj[ :revid ] }"
				emb.add_field( name: "Участник", value: obj[ :user ], inline: true )

				if obj[ :ns ] != 6 then
					emb.add_field( name: "Изменения:", value: "#{ obj[ :newlen ] - obj[ :oldlen ] } байт", inline: true )
					if obj[ :comment ] != "" then
						emb.add_field( name: "Описание правки", value: "#{ obj[ :comment ] }" )
					end
				end

				data[ 'servers' ].each do | id |
					if @channels[ id ][ 'recentchanges' ].nil? then next; end
					@bot.send_message( @channels[ id ][ 'recentchanges' ], '', false, emb )
				end
				sleep 1
			end

			@config[ 'wikies' ][ w ][ 'rcid' ] = last_rcid
			@client.save_config
		end

		def add_wiki( e, w )
			id = e.server.id
			w = w.gsub( /(http:\/\/|.wikia.com.*)/, '' )

			if @channels[ id ][ 'recentchanges' ].nil? then
				e.respond "<@#{ e.user.id }>, на сервере отсутствует канал #recentchanges, чтобы публиковать туда данные о свежих правках с вики. Пожалуйста, создайте канал и попробуйте снова."
				return
			end

			if @config[ 'wikies' ][ w ].nil? then
				@config[ 'wikies' ][ w ] = { 
					'rcid' => 0,
					'servers' => [ id ]
				}
			elsif @config[ 'wikies' ][ w ][ :servers ].include?( id ) then
				e.respond "<@#{ e.user.id }>, #{ w } уже есть в списке для патрулирования на этом сервере."
				return
			else
				@config[ 'wikies' ][ w ][ :servers ].push( id )
			end

			@client.save_config
			init_cheсking( w, @config[ 'wikies' ][ w ] )
			e.respond "<@#{ e.user.id }>, #{ w } добавлен в список для патрулирования."
		end

		def switch_uploads( e )
			@config[ 'show_uploads' ] = !@config[ 'show_uploads' ]
			@client.save_config

			e.respond "Отображение логов о загрузке изображений: #{ @config[ 'show_uploads' ] ? "включено" : "выключено" }."
		end
	end
end
