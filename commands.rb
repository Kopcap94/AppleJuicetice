module DiscordBot
  class Commands
    def initialize( client )
      @client = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config
    end

    def commands
      @bot.command( 
        :help,
        description: "Выводит справку о командах бота в ЛС участника.",
        usage: "Не требует параметров." 
      ) do | e | help( e, true ) end

      @bot.command( 
        :get_help,
        description: "Выводит справку о командах бота в чат.",
        usage: "Не требует параметров." 
      ) do | e | help( e, false ) end

      @bot.command(
        :info,
        description: "Выводит информацию о боте.",
        usage: "Не требует параметров." 
      ) do | e | bot_info( e ) end

      @bot.command(
        :avatar,
        min_args: 1,
        description: "Выводит ссылку на аватар участника.",
        usage: "Требуется упомянуть цель: !avatar @kopcap"
      ) do | e, u | avatar( e, u ) end

      @bot.command(
        :user,
        min_args: 1,
        description: "Выводит информация об участнике на Фэндоме.",
        usage: "Требуется указать ник участника: !user Kopcap94"
      ) do | e, *args | wiki_user( e, args.join( " " ) ) end

      @bot.command(
        :exclude_welcome,
        permission_level: 2,
        description: "Данная команда позволяет исключить сообщения о присоединении и выходе участников на/с сервера.",
        usage: "!exclude_welcome",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e | exclude( e ) end

      @bot.command(
        :ign,
        min_args: 1,
        permission_level: 3,
        description: "Данная команда доступна только хозяину бота. Игнорирует пользователя.",
        usage: "!ign @kopcap",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, u | ignore( e, u, true ) end

      @bot.command(
        :unign,
        min_args: 1,
        permission_level: 3,
        description: "Данная команда доступна только хозяину бота. Убирает игнор с пользователя.",
        usage: "!unign @kopcap",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, u | ignore( e, u, false ) end

      @bot.command(
        :eval,
        min_args: 1,
        permission_level: 3,
        description: "Данная команда доступна только хозяину бота.",
        usage: "!eval <код для выполнения>",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, *c | code_eval( e, c.join( ' ' ) ) end

      @bot.command(
        :cls,
        permission_level: 3,
        description: "Данная команда доступна только хозяину бота. Отчищает экран консоли.",
        usage: "!cls",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, *c |
        system "cls"
        e.message.create_reaction "\u2611"
      end

      @bot.command(
        :nuke,
        permission_level: 2,
        min_args: 1,
        description: "Удаляет указанное кол-во сообщений. Число сообщений для удаления должно быть в диапазоне от 2 до 100.",
        usage: "Требует указать число в диапазоне от 2 до 100: !nuke 10",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, i | nuke( e, i ) end
    end

    def help( e, s )
      t = s ? e.user.pm : e.channel

      t.send_embed do | emb |
        emb.color = "#4A804C"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'Список команд бота', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )

        @bot.commands.each do | k, v |
          text = "**Уровень доступа:** #{v.attributes[ :permission_level ] != 2 ? "все участники" : "модераторы и администраторы"}\n**Описание:** #{ v.attributes[ :description ] }\n**Использование:** #{ v.attributes[ :usage ] }"
          emb.add_field( name: "#{ @bot.prefix }#{ v.name }", value: text )
        end
      end

      if !e.channel.pm? and s then
        e.message.create_reaction "\u2611"
      end
    end

    def avatar( e, a )
      if a.to_s !~ /<@!?\d*>/ then
        e.respond "Неправильно выбран участник."
        return
      end

      a = parse( a )
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

    def exclude( e )
      id = e.server.id

      if @config[ 'exclude welcome' ].include? id then
        return;
      end

      @config[ 'exclude welcome' ].push( id )
      @client.save_config
      e.respond "Сервер исключён."
    end

    def nuke( e, a )
      return if e.channel.pm?

      a = parse( a )
      if a.to_s.empty? or a == 1 then
        a = 2
      elsif a > 100 then
        a = 100
      end

      e.channel.prune( a )
      e.respond "<@#{ e.user.id }>, чистка #{ a } сообщений выполнена."
    end

    def bot_info( e )
      e.channel.send_embed do | emb |
        emb.color = "#4A804C"

        emb.title = "#{ e.user.name }, Я - Яблочное Сокосудие!"
        emb.description = "Это бот, написанный на языке программирования Ruby. Основной фрейм для работы с Discord-ом - гем discordrb. Дополнительные гемы - HTTParty и JSON."

        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'AppleJuicetice', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: 'http://images2.wikia.nocookie.net/siegenax/ru/images/8/84/1_obey-giant_1024.png' )

        emb.add_field( name: "Исходный код бота", value: "https://github.com/Kopcap94/Discord-AJ" )

        emb.footer = Discordrb::Webhooks::EmbedFooter.new( text: "v1.0.4b" )
      end
    end

    def code_eval( e, c )
      begin
        eval c
      rescue => err
        system "cls"
        puts "Ошибка в коде #{ err }:\n#{ err.backtrace.join( "\n" ) }"
      end
    end

    def ignore( e, u, s )
      u = parse( u )

      if u == @config[ 'owner' ] then
        e.respond "Я бы рад..."
        return
      elsif s and @bot.ignored?( u ) then
        e.respond "Участник уже в списке игнора."
        return
      elsif s then
        @bot.ignore_user( u )
        @config[ 'ignored' ].push( u )
      else
        @bot.unignore_user( u )
        @config[ 'ignored' ].delete( u )
      end

      @client.save_config
      e.respond "Участник #{ @bot.users[ u ].username } #{ s ? "добавлен в игнор" : "убран из игнора" }."
    end

    def parse( i )
      return i.gsub( /[^0-9]/, '' ).to_i
    end
  end
end