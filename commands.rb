module DiscordBot
	module Commands
	  class Commands
		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config
		end

		def help( e )
			e.user.pm.send_embed do | emb |
				emb.color = "#4A804C"
				emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'Список команд бота', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )

				@bot.commands.each do | k, v |
					text = "**Уровень доступа:** #{v.attributes[ :permission_level ] != 2 ? "все участники" : "модераторы и администраторы"}\n**Описание:** #{ v.attributes[ :description ] }\n**Использование:** #{ v.attributes[ :usage ] }"
					emb.add_field( name: "#{ @bot.prefix }#{ v.name }", value: text )
				end
			end

			e.respond "<@#{ e.user.id }>, список команд отправлен в ЛС."
		end

		def add_group( e, g )
			puts e.server.id
			if g !~ /^-?\d+$/ then
				e.respond "Неправильно указан ID группы. Пример: -223994."
				return
			end

			if g.index( "-" ).nil? then
				e.respond "В самом начале ID группы пропущен '-'. Пожалуйста, не забудьте его в следующий раз."
				g = "-" + g
			end

			@config[ 'groups' ][ g ] = ""
			@client.save_config

			e.respond "<@#{ e.user.id }>, ID группы #{ g } добавлен в список групп для новостей."
		end

		def avatar( e, a )
			if a.to_s !~ /<@!?\d*>/ then
				e.respond "Неправильно выбран участник."
				return
			end

			a = a.gsub( /[^\d]+/, "" ).to_i
			u = @bot.users.find { | u | u[ 0 ] == a }
			if u.nil? then
				e.respond "<@#{ e.user.id }>, такого участника нет на сервере."
				return
			end
			e.respond "<@#{ e.user.id }>, https://cdn.discordapp.com/avatars/#{ a }/#{ u[ 1 ].avatar_id }.jpg?size=512"
		end

		def wiki_user( e, u )
			us = JSON.parse(
				HTTParty.get(
					URI.encode( "http://community.wikia.com/api.php?action=query&format=json&list=users&usprop=registration|editcount&ususers=#{ u }" ),
					:verify => false
				).body,
				:symbolize_names => true
			)[ :query ][ :users ][0]
			
			if !us[ :missing ].nil? then
				e.respond "Участника #{ u } не существует."
				return
			end

			e.channel.send_embed do | emb |
				emb.color = "#4A804C"
				emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "#{ u } [ ID: #{ us[ :userid ] } ]", url: "http://community.wikia.com/wiki/User:#{ u.gsub( /\s/, "_" ) }" )
				emb.add_field( name: "Регистрация", value: "#{ us[:registration].nil? ? "отключён" : us[ :registration ].gsub( /[TZ]/, " " ) }", inline: true )
				emb.add_field( name: "Кол-во правок", value: us[ :editcount ], inline: true )
			end
		end

		def switch_uploads( e )
			@config[ 'show_uploads' ] = !@config[ 'show_uploads' ]
			@client.save_config

			e.respond "Отображение логов о загрузке изображений: #{ @config[ 'show_uploads' ] ? "включено" : "выключено" }."
		end

		def nuke( e, a )
			a = a.gsub( /[^0-9]/, '' ).to_i
			if a.nil? or a == '' or a == 1 then
				a = 2
			elsif a > 100 then
				a = 100
			end

			e.channel.prune( a )
			e.respond "<@#{ e.user.id }>, чистка #{ a } сообщений выполнена."
		end

		def set_time( e, t, i )
			if [ "vk", "rc" ].index( t ).nil? then
				e.respond "<@#{ e.user.id }>, доступные варианты для изменения задержки между запросами - vk и rc [ запросы ВК, запросы к свежим правкам ]. Пример команды !set_time vk 10."
				return
			end

			num = i.gsub( /[^0-9]/, '' ).to_i
			if num == "" then num = 60 end

			@config[ t + "_refresh" ] = num
			@client.save_config

			e.respond "<@#{ e.user.id }>, запросы к #{ t } будут повторяться каждые #{ num } секунд."
		end

		def bot_info( e )
			e.channel.send_embed do | emb |
				emb.color = "#4A804C"

				emb.title = "#{ e.user.name }, Я - Яблочное Сокосудие!"
				emb.description = "Это бот, написанный на языке программирования Ruby. Основной фрейм для работы с Discord-ом - гем discordrb. Дополнительные гемы - HTTParty и JSON."

				emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'AppleJuicetice', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
				emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )

				emb.add_field( name: "Исходный код бота", value: "https://github.com/Kopcap94/Discord-AJ" )

				emb.footer = Discordrb::Webhooks::EmbedFooter.new( text: "v1.0.1", icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
			end
		end
	  end
	end
end