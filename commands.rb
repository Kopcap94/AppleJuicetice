module DiscordBot
  class Commands
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config
      @thr = client.thr
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
        :drop,
        permission_level: 2,
        description: "С помощью данной команды бот покинет ваш сервер.",
        usage: "!drop",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e | drop( e ) end

      @bot.command(
        :empty,
        permission_level: 2,
        description: "Данная команда позволит вывести список пустых ролей на сервере.",
        usage: "!empty",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e | empty_roles( e ) end

      @bot.command(
        :nuke,
        permission_level: 2,
        min_args: 1,
        description: "Удаляет указанное кол-во сообщений. Число сообщений для удаления должно быть в диапазоне от 2 до 100.",
        usage: "Требует указать число в диапазоне от 2 до 100: !nuke 10",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, i | nuke( e, i ) end

      @bot.command(
        :bl,
        permission_level: 3,
        usage: "!bl <id>",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, id | blacklist( e, id ) end

      @bot.command(
        :ign,
        min_args: 1,
        permission_level: 3,
        usage: "!ign @kopcap",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, u | ignore( e, u, true ) end

      @bot.command(
        :unign,
        min_args: 1,
        permission_level: 3,
        usage: "!unign @kopcap",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, u | ignore( e, u, false ) end

      @bot.command(
        :eval,
        min_args: 1,
        permission_level: 3,
        usage: "!eval <код для выполнения>",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, *c | code_eval( e, c.join( ' ' ) ) end

      @bot.command(
        :cls,
        permission_level: 3,
        usage: "!cls",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e |
        Gem.win_platform? ? ( system "cls" ) : ( system "clear && printf '\e[3J'" )
        e.message.create_reaction "\u2611"
      end

      @bot.command(
        :die,
        permission_level: 3
      ) do | e | die( e ) end

      @bot.command(
        :server,
        permission_level: 3
      ) do | e | stats( e ) end
    end

    def help( e, s )
      t = s ? e.user.pm : e.channel

      t.send_embed do | emb |
        emb.color = "#4A804C"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'Список команд бота', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )

        @bot.commands.each do | k, v |
          next if v.attributes[ :permission_level ] == 3

          text = "**Уровень доступа:** #{ v.attributes[ :permission_level ] != 2 ? "все участники" : "модераторы и администраторы" }\n**Описание:** #{ v.attributes[ :description ] }\n**Использование:** #{ v.attributes[ :usage ] }"
          emb.add_field( name: "#{ @bot.prefix }#{ v.name }", value: text )
        end
      end

      if !e.channel.pm? and s then
        e.message.create_reaction "\u2611"
      end
    end

    def empty_roles( e )
      roles = []

      @bot.servers[ e.server.id ].roles.each do | r | 
        roles.push( r.name ) if r.members.length == 0 && r.name !~ /everyone$/
      end

      if roles.empty? then
        e.respond "На сервере отсутствуют пустые роли."
      else
        e.respond roles.join( "\n" );
      end
    end

    def die( e )
      @c.thr.each {| k, thr | thr.kill }
      e.respond "Перезапускаюсь."
      exit
    end

    def stats( e )
      ram = %x{ free }.lines.to_a[ 1 ].split[ 1, 3 ].map { | v | ( v.to_f / 1024.0 ).to_i }
      cpu = %x{ top -n1 }.lines.find{ | l | /Cpu\(s\):/.match( l ) }.split[ 1 ]
      upt = %x{ uptime -p }.sub( "up ", "" )

      e.channel.send_embed do | emb |
        emb.color = "#FFA500"

        emb.title = "Текущая статистика сервера"
        emb.add_field( name: "CPU", value: "#{ cpu }%", inline: true )
        emb.add_field( name: "RAM", value: "#{ ram[ 1 ] }/#{ ram[ 0 ] } mb [#{ ( ( ram[ 1 ].to_f * 100.0 ) / ram[ 0 ].to_f ).to_i }%]", inline: true )
        emb.add_field( name: "Uptime", value: upt, inline: false )

        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'AppleJuicetice', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
      end
    end

    def avatar( e, a )
      if a.to_s !~ /<@!?\d*>/ and a.to_s !~ /^\d{18,}/ then
        e.respond "Неправильно выбран участник."
        return
      end

      a = @c.parse( a )
      u = @bot.users.find { | u | u[ 0 ] == a }

      if u.nil? then
        e.respond "<@#{ e.user.id }>, такого участника нет на сервере."
        return
      end

      e.respond "<@#{ e.user.id }>, https://cdn.discordapp.com/avatars/#{ a }/#{ u[ 1 ].avatar_id }.jpg?size=512"
    end

    def blacklist( e, id = nil )
      id = id.nil ? e.server.id.to_s : id

      id = @c.parse( id )
      if @config[ 'blacklisted' ].include?( id ) then
        e.respond "Сервер уже числится в чёрном списке."
        return
      end

      @config[ 'blacklisted' ].push( id )
      @c.save_config

      e.respond "Сервер #{ id } добавлен в чёрный список."

      if !@channels[ id ].nil? then
        e.respond "В данный момент я нахожусь на том сервере. Выхожу..."
        @bot.servers[ id ].leave
      end
    end

    def drop( e )
      if e.channel.pm? then return; end
      e.respond "Покидаю сервер."
      @bot.servers[ e.server.id ].leave
    end

    def nuke( e, a )
      return if e.channel.pm?

      a = @c.parse( a )
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
        emb.description = "Это бот, написанный на языке программирования Ruby. Основной фрейм для работы с Discord-ом - гем discordrb. Дополнительные гемы - HTTParty и Down."

        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'AppleJuicetice', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )
        emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: 'http://images2.wikia.nocookie.net/siegenax/ru/images/8/84/1_obey-giant_1024.png' )

        emb.add_field( name: "Исходный код бота", value: "https://github.com/Kopcap94/Discord-AJ" )
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
      u = @c.parse( u )

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

      @c.save_config
      e.respond "Участник #{ @bot.users[ u ].username } #{ s ? "добавлен в игнор" : "убран из игнора" }."
    end
  end
end
