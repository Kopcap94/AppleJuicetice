module DiscordBot
	module Commands
	  class Commands
		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config
		end

		def new_user_join( e )
			g = e.server.roles.find { |r| r.name == "Новички" }
			e.user.add_role( g )
			e.server.general_channel.send_message "Добро пожаловать на сервер, <@#{e.user.id}>. Пожалуйста, предоставьте ссылку на свой профиль в Фэндоме, чтобы администраторы могли добавить вас в группу."
		end

		def user_left( e )
			e.server.general_channel.send_message "<@#{e.user.id}> покинул сервер."
		end

		def mentioned( e )
			e.respond "<@#{ e.user.id }>, если вам требуется список команд, используйте команду !help."
		end

		def help( e )
			e.user.pm "Список команд пустует"
			e.respond "<@#{ e.user.id }>, список команд отправлен в ЛС."
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
			u = @bot.users.find { | u | u[ 0 ] == a }[ 1 ].avatar_id
			e.respond "<@#{ e.user.id }>, https://cdn.discordapp.com/avatars/#{ a }/#{ u }.jpg?size=512"
		end

		def switch_uploads( e )
			@config[ 'show_uploads' ] = !@config[ 'show_uploads' ]
			@client.save_config

			e.respond "Отображение логов о загрузке изображений: #{ @config[ 'show_uploads' ] ? "включено" : "выключено" }."
		end
	  end
	end
end