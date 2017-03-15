require 'httparty'
require 'json'

module DiscordBot
	module VK
	  class VK
		include HTTParty

		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config
		end

		def commands
			@bot.command(
				:add_group,
				permission_level: 2,
				min_args: 1,
				description: "Добавляет ID группы VK в список патрулируемых.",
				usage: "Требует ID группы: !add_group -2000"
			) do | e, g | add_group( e, g ) end
		end

		def start_group_gathering
			Thread.new {
				@config[ 'groups' ].each do |k, v|
					do_new_thread( k, v )
				end
			}
		end

		def do_new_thread( t, d )
			Thread.new {
				begin
					get_data_from_group( t, d )
				rescue => err
					puts "#{ err } at #{ t }: #{ err.backtrace }"
				end

				sleep 300
				do_new_thread( t, d )
			}
		end

		def get_data_from_group( g, d )
			r =  JSON.parse(
				HTTParty.get(
					"https://api.vk.com/method/wall.get?owner_id=#{ g }&count=1&offset=1&extended=1",
					:verify => false
				).body,
				:symbolize_names => true
			)[ :response ]

			if r.nil? then
				return
			end
			resp = r[ :wall ][ 1 ]

			if d[ 'id' ] == resp[ :id ] then
				return
			end

			emb = Discordrb::Webhooks::Embed.new
			emb.color = "#507299"
			emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: r[ :groups ][ 0 ][ :name ], url: "http://vk.com/#{ r[ :groups ][ 0 ][ :screen_name ] }" )
			emb.title = "http://vk.com/wall#{ g }_#{ resp[ :id ] }"
			emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "#{ r[ :groups ][ 0 ][ :photo_big ] }" )

			text = resp[ :text ].gsub( "<br>", "\n" ).gsub( /(#[^\s]+([\s\n]*)?|\|\s*)/, "" )
			if text != "" then 
				if text.length > 100 then text = text[0..100] end
				emb.add_field( name: "Текст поста:", value: text )
			end

			attach = resp[ :attachments ]
			if !attach.nil? then
				attach = attach[ 0 ]

				case attach[ :type ]
				when "photo"
					p = attach[ :photo ][ :src_big ] 

					emb.add_field( name: "Изображение", value: p )
					emb.image = Discordrb::Webhooks::EmbedImage.new( url: p )
				when "video"
					p = attach[ :video ]

					emb.add_field( name: "Видео", value: "http://vk.com/video#{ g }_#{ p[ :vid ] }" )
					emb.add_field( name: "Название", value: p[ :title ] )
					emb.image = Discordrb::Webhooks::EmbedImage.new( url: p[ :image_big ] ) 
				when "doc"
					p = attach[ :doc ]

					emb.add_field( name: "Документ", value: p[ :url ] )
					emb.add_field( name: "Название", value: p[ :title ] )
				end
			end

			d[ 'servers' ].each do | serv | 
				@bot.send_message( @channels[ serv ][ 'news' ], '', false, emb )
			end

			@config[ 'groups' ][ g ][ 'id' ] = resp[ :id ]
			@client.save_config
		end

		def add_group( e, g )
			if g !~ /^-?\d+$/ then
				e.respond "Неправильно указан ID группы. Пример: -223994."
				return
			end

			if g.index( "-" ).nil? then
				e.respond "В самом начале ID группы пропущен '-'. Пожалуйста, не забудьте его в следующий раз."
				g = "-" + g
			end

			if @config[ 'groups' ][ g.to_s ].nil? then
				@config[ 'groups' ][ g.to_s ] = { 'id' => "", 'servers' => [] }
			end

			@config[ 'groups' ][ g.to_s ][ 'servers' ].push( e.server.id )
			@client.save_config

			e.respond "<@#{ e.user.id }>, ID группы #{ g } добавлен в список групп для новостей."
		end
	  end
	end
end