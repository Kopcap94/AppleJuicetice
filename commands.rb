module DiscordBot
  class Commands
    def initialize( client )
      @c = client
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
        :ew,
        permission_level: 2,
        description: "Данная команда позволяет исключить сообщения о присоединении и выходе участников на/с сервера.",
        usage: "!ew",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e | exclude( e ) end

      @bot.command(
        :bl,
        permission_level: 3,
        usage: "!bl <id>",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, id | blacklist( e, id ) end

      @bot.command(
        :drop,
        permission_level: 2,
        description: "С помощью данной команды бот покинет ваш сервер.",
        usage: "!drop",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e | drop( e ) end

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
      ) do | e, *c |
        Gem.win_platform? ? ( system "cls" ) : ( system "clear" )
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

      @bot.command(
        :die,
        permission_level: 3
      ) do | e | die( e ) end

      @bot.command(
        :online,
        min_args: 1,
        description: "Определяет информацию о доступности сервера STEAM.",
        usage: "!online 192.168.0.1:27015"
      ) do | e, ip | check_online( e, ip.to_s ) end
      
    end

    def help( e, s )
      t = s ? e.user.pm : e.channel

      t.send_embed do | emb |
        emb.color = "#4A804C"
        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'Список команд бота', url: 'https://github.com/Kopcap94/Discord-AJ', icon_url: 'http://images3.wikia.nocookie.net/siegenax/ru/images/2/2c/CM.png' )

        @bot.commands.each do | k, v |
          if v.attributes[ :permission_level ] == 3 or ( !v.attributes[ :parameters ].nil? and v.attributes[ :parameters ][ :hidden ] ) then next; end

          text = "**Уровень доступа:** #{v.attributes[ :permission_level ] != 2 ? "все участники" : "модераторы и администраторы"}\n**Описание:** #{ v.attributes[ :description ] }\n**Использование:** #{ v.attributes[ :usage ] }"
          emb.add_field( name: "#{ @bot.prefix }#{ v.name }", value: text )
        end
      end

      if !e.channel.pm? and s then
        e.message.create_reaction "\u2611"
      end
    end

    def die( e )
      e.respond "Перезапускаюсь."
      exit
    end

    def avatar( e, a )
      if a.to_s !~ /<@!?\d*>/ then
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

    def exclude( e )
      id = e.server.id

      if @config[ 'exclude welcome' ].include? id then
        return;
      end

      @config[ 'exclude welcome' ].push( id )
      @c.save_config
      e.respond "Сервер исключён."
    end

    def blacklist( e, id = nil )
      if id.nil? then
        id = e.server.id.to_s
      end

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
        emb.description = "Это бот, написанный на языке программирования Ruby. Основной фрейм для работы с Discord-ом - гем discordrb. Дополнительные гемы - HTTParty и JSON."

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

    def check_online( e, a )
      if a =~ /^@\d$/ then
        o = {
          '@1' => {
            'ip' => '193.70.6.12',
            'port' => '2546'
          },
          '@2' => {
            'ip' => '193.70.6.12',
            'port' => '2746'
          }
        }

        if o[ a ].nil? then
          e.respond "Неправильный номер сервера. Доступные номера: #{ o.keys.join( ', ' ) }."
          return
        end

        ip = o[ a ][ 'ip' ]
        port = o[ a ][ 'port' ]
      elsif a =~ /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}:\d{1,5}$/ then
        a = a.split( ':' )
        ip = a[ 0 ]
        port = a[ 1 ].to_i + 1
      else
        e.respond "Неправильный формат адреса. Пример: 192.168.0.1:27015"
        return
      end

      d = JSON.parse(
        HTTParty.post(
          "http://dz.launcher.eu/check",
          :body => { 'serverip' => "#{ ip }:#{ port }" }
        ).body,
        :symbolize_names => true
      )

      if d[ :status ] != "success" then
        e.respond "Сервер выключен или ушёл на рестарт."
        return
      end

      s = d[ :server ]

      e.channel.send_embed do | emb |
        emb.color = "#4A804C"
        emb.title = s[ :name ]
        emb.description = "**Онлайн:** #{ s[ :players ] }/#{ s[ :playersmax ] }\n**Карта:** #{ s[ :map ] }"
      end
    end
  end
end