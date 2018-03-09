module DiscordBot
  class VK
    include HTTParty

    def initialize( client )
      @client = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config
      @thr = client.thr
      @names = [ 'vk-news', 'вк-новости', 'новости' ]

      for_init
    end

    def commands
      @bot.command(
        :add_group,
        permission_level: 2,
        min_args: 1,
        description: "Добавляет ID группы VK в список патрулируемых.",
        usage: "Требует ID группы: !add_group -2000",
        permission_message: "Недостаточно прав, чтобы использовать эту команду."
      ) do | e, g |
        begin
          add_group( e, g )
        rescue => err
          puts "[add vk] #{ err }"
          e.respond "При попытке добавления группы произошла ошибка. Возможно, файл конфигураций занят. Попробуйте позже."
        end
      end
    end

    def for_init
      thr = []

      @thr[ 'vk' ] = Thread.new {
        @config[ 'groups' ].clone.each do | k, v |
          if k == 'access_token' then next; end

          thr << Thread.new {
            begin
              get_data_from_group( k )
            rescue => err
              @client.error_log( err, "VK" )
            end
          }

          sleep 60
        end

        thr.each { | t | t.join }
        for_init
      }
    end

    def get_data_from_group( g )
      r = JSON.parse(
        HTTParty.get(
          "https://api.vk.com/method/wall.get?owner_id=#{ g }&count=2&offset=0&extended=1&v=5.7&access_token=" + @config[ 'groups' ][ 'access_token' ],
          :verify_peer => false
        ).body,
        :symbolize_names => true
      )[ :response ]

      if r.nil? or r[ :items ].empty? then
        return
      end

      resp = r[ :items ][ 0 ]
      d = @config[ 'groups' ][ g ]

      if !resp[ :is_pinned ].nil? and d[ 'id' ] >= resp[ :id ] then
        resp = r[ :items ][ 1 ]
      end

      if resp.nil? or d[ 'id' ] >= resp[ :id ] then
        return
      end

      @config[ 'groups' ][ g ][ 'id' ] = resp[ :id ]
      @client.save_config

      emb = Discordrb::Webhooks::Embed.new
      emb.color = "#507299"
      emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: r[ :groups ][ 0 ][ :name ], url: "http://vk.com/#{ r[ :groups ][ 0 ][ :screen_name ] }" )
      emb.title = "http://vk.com/wall#{ g }_#{ resp[ :id ] }"
      emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "#{ r[ :groups ][ 0 ][ :photo_100 ] }" )

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
          p = attach[ :photo ]
          img = p.keys.map {| v | v if v =~ /photo_/ }.compact[ -1 ]

          emb.add_field( name: "Изображение", value: p[ img ] )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: p[ img ] )
        when "video"
          p = attach[ :video ]
          img = p.keys.map {| v | v if v =~ /photo_/ }.compact[ -1 ]

          emb.add_field( name: "Видео", value: "http://vk.com/video#{ g }_#{ p[ :id ] }" )
          emb.add_field( name: "Название", value: p[ :title ] )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: p[ img ] ) 
        when "doc"
          p = attach[ :doc ]

          emb.add_field( name: "Документ", value: p[ :url ] )
          emb.add_field( name: "Название", value: p[ :title ] )
        end
      end

      d[ 'servers' ].each do | serv |
        if @channels[ serv ].nil? then next; end

        s_ch = @channels[ serv ].keys
        channel = s_ch & @names

        if channel.empty? then next; end
        msg = @bot.send_message( @channels[ serv ][ channel[ 0 ] ], '', false, emb )
        msg.react '❤'
      end
    end

    def add_group( e, g )
      if e.channel.pm? then 
        return;
      elsif g !~ /^-?\d+$/ then
        e.respond "Неправильно указан ID группы. Пример: -223994."
        return
      end

      id = e.server.id
      s_ch = @channels[ id ].keys
      channel = s_ch & @names

      if channel.empty? then
        e.respond "Отсутствует канал для новостей. Чтобы воспользоваться данной командой, создайте канал с один из названий #{ @names.join( ', ' ) }."
        return
      end

      if g.index( "-" ).nil? then
        e.respond "В самом начале ID группы пропущен '-'. Пожалуйста, не забудьте его в следующий раз."
        g = "-" + g
      end

      if @config[ 'groups' ][ g.to_s ].nil? then
        @config[ 'groups' ][ g.to_s ] = { 'id' => 0, 'servers' => [] }
      end

      if @config[ 'groups' ][ g.to_s ][ 'servers' ].include?( id ) then
        e.respond "Данная группа уже числится в списке вашего сервера."
        return
      end

      @config[ 'groups' ][ g.to_s ][ 'servers' ].push( id )
      @client.save_config

      e.respond "<@#{ e.user.id }>, ID группы #{ g } добавлен в список групп для новостей."
    end
  end
end
