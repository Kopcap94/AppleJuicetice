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

		def start_group_gathering
			Thread.new {
				@config[ 'groups' ].each do |k, v|
					do_new_thread( k )
					sleep 10
				end

				sleep 300
				start_group_gathering
			}
		end

		def do_new_thread( t )
			Thread.new {
				get_data_from_group( t )
			}
		end

		def get_data_from_group( g )
			r =  JSON.parse(
				HTTParty.get(
					"https://api.vk.com/method/wall.get?owner_id=#{ g }&count=1&offset=1&extended=1",
					:verify => false
				).body,
				:symbolize_names => true
			)[ :response ]
			resp = r[ :wall ][ 1 ]

			if @config[ 'groups' ][ g ] == resp[ :id ] then
				puts "Данная тема уже была опубликована в канале. Возвращаемся..."
				return true
			end

			message = "#{ r[ :groups ][ 0 ][ :name ] }:\nСсылка на пост: http://vk.com/wall#{ g }_#{ resp[ :id ] }\n"
			attach = resp[ :attachments ][ 0 ]

			if resp[ :text ] != "" then message = message + "#{ resp[ :text ] }\n" end

			case attach[ :type ]
			when "photo"
				p = attach[ :photo ]

				image = "Изображение: #{ p[ :src_big ] }\n"
				text = ""

				if p[ :text ] != '' then
					text = "Комментарий к изображению: #{ p[ :text ] }\n"
				end

				message = message + text + image
			when "video"
				p = attach[ :video ]

				url = "Видео: http://vk.com/video#{ g }_#{ p[ :id ] }\n"
				title = "Название: #{ p[ :title ] }\n"
				img = p[ :image_big ]

				message = message + title + url
			when "doc"
				p = attach[ :doc ]

				title = "Название: #{ p[ :title ] }\n"
				url = "Ссылка: #{ p[ :url ] }\n"

				message = message + title + url
			end

			@bot.send_message( @channels[ 'news' ], message )

			@config[ 'groups' ][ g ] = resp[ :id ]
			@client.save_config
		end
	  end
	end
end