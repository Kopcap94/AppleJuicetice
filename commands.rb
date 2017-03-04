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
	  end
	end
end