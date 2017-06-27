module DiscordBot
  class Wiki
    include HTTParty

    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config

      for_init
    end

    def commands
      @bot.command(
        :add_wiki,
        permission_level: 2,
        min_args: 1,
        description: "Добавляет вики в список патрулируемых и выводит правки в канал #recentchanges.",
        usage: "!add_wiki ru.mlp",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, w | add_wiki( e, w ) end

      @bot.command(
        :attr_wiki,
        permission_level: 2,
        min_args: 2,
        description: "Изменяет переменную отображения загрузок (uploads) и логов (logs).",
        usage: "!attr_wiki ru.mlp logs",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, w, t | attr_wiki( e, w, t ) end
    end

    def for_init
      Thread.new {
        @config[ 'wikies' ].each do | w, r |
          init_checking( w, r )
        end
      }
    end
    
    def init_checking( w, d )
      Thread.new {
        begin
          get_data_from_api( w, d )
        rescue => err
          @c.error_log( err, "WIKI" )
        end

        sleep 60
        init_checking( w, @config[ 'wikies' ][ w ] )
      }
    end

    def get_data_from_api( w, data )
      d =  JSON.parse(
        HTTParty.get(
          "http://#{ w }.wikia.com/api.php?action=query&list=recentchanges&rclimit=50&rcprop=user|title|timestamp|ids|comment|sizes|loginfo&format=json",
          :verify => false
        ).body,
        :symbolize_names => true
      )[ :query ][ :recentchanges ]

      rcid = data[ 'rcid' ]
      show_uploads = @config[ 'show_uploads' ]
      last_rcid = d[ 0 ][ :rcid ]

      if rcid == 0 then
        @config[ 'wikies' ][ w ][ 'rcid' ] = last_rcid
        @c.save_config
        return
      end

      if last_rcid <= rcid then
        return
      end

      d.reverse.each do | obj |
        if( obj[ :rcid ] <= rcid ) or
          ( obj[ :revid ] == 0 and !data[ 'logs' ] ) or
          ( obj[ :type ] == 'log' and obj[ :logtype ] == 'upload' and !data[ 'uploads' ] ) or
          ( obj[ :user ] == 'WikiaBot' or obj[ :user ] == 'Wikia' )
          next
        end

        emb = Discordrb::Webhooks::Embed.new

        if obj[ :type ] != 'log' then
          emb.color = "#507299"

          title = "[ #{ w } ] #{ obj[ :title ] }"
          if [ 110, 111, 1200, 1201, 1202, 2001, 2002 ].index( obj[ :ns ] ) then title = "[ #{ w } ] Тема на форуме или стене обсуждения" end

          emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: title, url: "http://#{ w }.wikia.com/index.php?title=#{ obj[ :title ].gsub( /\s/, "_" ) }" )
          emb.title = "http://#{ w }.wikia.com/index.php?diff=#{ obj[ :revid ] }"
          emb.add_field( name: "Изменения:", value: "#{ obj[ :newlen ] - obj[ :oldlen ] } байт", inline: true )
        else
          emb.color = "#759B01"

          name = ""
          url = ""
          title = ""
          value = ""

          case obj[ :logtype ]
          when "wikifeatures"
            name = "WikiFeatures"
            url = "wikifeatures"
            title = "Опция"
            value = obj[ :comment ].gsub( /^[^:]+:/, '' ).to_s
          when "move"
            name = "переименования"
            url = "move"
            title = "Переименована страница"
            value = obj[ :title ]
          when "delete"
            name = "удаления"
            url = "delete"
            title = "#{ obj[ :logaction ] == 'delete' ? "Удалена" : "Восстановлена" } страница"
            value = obj[ :title ]
          when "protect"
            name = "защиты"
            url = "protect"
            title = obj[ :logaction ] == 'protect' ? "Защищена страница" : "Снята защита"
            value = obj[ :title ]
          when "block"
            name = "блокировок"
            url = "block"
            title = obj[ :logaction ] == 'block' ? "Заблокирован" : "Разблокирован"
            value = obj[ :title ].gsub( /^[^:]+:/, '' )
          when "upload"
            name = "загрузок"
            url = "upload"
            title = obj[ :logaction ] == 'upload' ? "Загружен файл" : "Перезаписан файл"
            value = obj[ :title ].gsub( /^[^:]+:/, '' )
          else
            next
          end

          emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "[ #{ w } ] Лог #{ name }", url: "http://#{ w }.wikia.com/wiki/Special:Log/#{ url }" )
          emb.add_field( name: title, value: value, inline: true )

          # Blocks
          if obj[ :logaction ] == 'block' then
            emb.add_field( name: "Истекает", value: obj[ :block ][ :expiry ], inline: true )
          end
        end

        emb.add_field( name: "Выполнил", value: obj[ :user ], inline: true )
        if obj[ :comment ].gsub( /^\s+/, '' ) != "" then
          emb.add_field( name: "Описание", value: "#{ obj[ :comment ][ 0..100 ] }" )
        end

        data[ 'servers' ].each do | id |
          if @channels[ id ].nil? or @channels[ id ][ 'recentchanges' ].nil? then next; end
          @bot.send_message( @channels[ id ][ 'recentchanges' ], '', false, emb )
        end
        sleep 1
      end

      @config[ 'wikies' ][ w ][ 'rcid' ] = last_rcid
      @c.save_config
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
          'uploads' => true,
          'logs' => true,
          'servers' => [ id ]
        }
      elsif @config[ 'wikies' ][ w ][ 'servers' ].include?( id ) then
        e.respond "<@#{ e.user.id }>, #{ w } уже есть в списке для патрулирования на этом сервере."
        return
      else
        @config[ 'wikies' ][ w ][ 'servers' ].push( id )
      end

      @c.save_config
      init_checking( w, @config[ 'wikies' ][ w ] )
      e.respond "<@#{ e.user.id }>, #{ w } добавлен в список для патрулирования."
    end

    def attr_wiki( e, w, t )
      if @config[ 'wikies' ][ w ].nil? then
        e.respond "Такого вики-проекта не существует."
        return
      elsif ![ 'uploads', 'logs' ].include?( t ) then
        e.respond "Таких параметров не существует. Предлагаемые параметры: uploads, logs."
        return
      end

      s = @config[ 'wikies' ][ w ][ t ]
      @config[ 'wikies' ][ w ][ t ] = !s

      @c.save_config
      e.respond "Значение параметра #{ t } для вики #{ w } теперь #{ !s }."
    end
  end
end