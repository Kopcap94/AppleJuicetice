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
      ) do | e |
        Gem.win_platform? ? ( system "cls" ) : ( system "clear && printf '\e[3J'" )
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
        description: "Выводит информацию об онлайне серверов. Требуется ввести номер сервера.",
        usage: "!online 1",
        parameters: {
          hidden: true
        }
      ) do | e, *s | 
        if [ 343404836894801920, 321949136838459392 ].include? e.server.id then
          check_online( e, s )
        end
      end
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
      @c.thr.each {| k, thr | thr.kill }
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

    def check_online( e, arr )
      o = {
        '1' => 1431093,
        '2' => 1907245
      }

      s = arr[ 0 ]

      if o[ s ].nil? then
        e.respond "Неправильно указан номер сервера. Доступные номера серверов: #{ o.keys.join( ', ' ) }."
        return
      end

      s_check = ( !arr[ 1 ].nil? && arr[ 1 ] == '-s' ) ? true : false 

      d = JSON.parse(
        HTTParty.get(
          "https://api.battlemetrics.com/servers/#{ o[ s ] }?include=player",
          :verify_peer => false
        ).body,
        :symbolize_names => true
      )

      serv = d[ :data ][ :attributes ]
      players = d[ :included ]

      arr = Array.new( 6 ) { Array.new }
      cur = 0

      players.each do | obj |
        if arr[ cur ].length >= 10 then
          cur = cur + 1
        end

        player_name = obj[ :attributes ][ :name ]
        if s_check then
          score = 0

          obj[ :meta ][ :metadata ].each do | obj |
            if obj[ :key ] == 'score' then
              score = obj[ :value ]
            end
          end

          player_name = "#{ player_name } [#{ score }]"
        end

        arr[ cur ].push( player_name )
      end

      e.channel.send_embed do | emb |
        emb.color = "#4A804C"

        emb.add_field( name: "Онлайн", value: "#{ serv[ :players ] }/#{ serv[ :maxPlayers ] }", inline: true )
        emb.add_field( name: "IP/Port", value: "#{ serv[ :ip ] }:#{ serv[ :port ] }", inline: true )
        emb.add_field( name: "Сервер", value: serv[ :details ][ :mission ] )
        emb.add_field( name: "Моды", value: serv[ :details ][ :mods ].map { | val | if ( /DayZ/ =~ val && /@/ !~ val ) then val end }.compact.join( "\n" ) )

        counter = 1
        arr.each_with_index do | list, ind |
          break if list.empty?
          emb.add_field( name: ( ind == 0 ) ? "[ Игроки ]":"#", value: list.map.with_index{ | p, i | "**#{ i + counter }**. #{ p }" }.join( "\n" ), inline: true )
          counter = counter + 10
        end

        emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: 'DayZ Epoch RU 174', url: 'https://vk.com/epoch_ru174', icon_url: 'https://pp.userapi.com/c636518/v636518986/55ebe/C2exL6Yrhbs.jpg' )
      end
    end
  end
end
