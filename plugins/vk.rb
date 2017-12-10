module DiscordBot
  class VK
    include HTTParty

    def initialize( client )
      @client = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config
      @thr = client.thr

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
      ) do | e, g | add_group( e, g ) end
    end

    def for_init
      thr = []

      @thr[ 'vk' ] = Thread.new {
        @config[ 'groups' ].each do | k, v |
          if k == 'access_token' then next; end

          thr << Thread.new {
            begin
              get_data_from_group( k )
            rescue => err
              @client.error_log( err, "VK" )
            end
          }

          sleep 20
        end

        thr.each { | t | t.join }
        for_init
      }
    end

    def get_data_from_group( g )
      r = JSON.parse(
        HTTParty.get(
          "https://api.vk.com/method/wall.get?owner_id=#{ g }&count=1&offset=1&extended=1&access_token=" + @config[ 'groups' ][ 'access_token' ],
          :verify => false
        ).body,
        :symbolize_names => true
      )[ :response ]

      if r.nil? then
        return
      end

      resp = r[ :wall ][ 1 ]
      d = @config[ 'groups' ][ g ]

      if d[ 'id' ] >= resp[ :id ] then
        return
      end

      @config[ 'groups' ][ g ][ 'id' ] = resp[ :id ]
      @client.save_config

      emb = Discordrb::Webhooks::Embed.new
      emb.color = "#507299"
      emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: r[ :groups ][ 0 ][ :name ], url: "http://vk.com/#{ r[ :groups ][ 0 ][ :screen_name ] }" )
      emb.title = "http://vk.com/wall#{ g }_#{ resp[ :id ] }"
      emb.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new( url: "#{ r[ :groups ][ 0 ][ :photo_big ] }" )

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
          p = attach[ :photo ][ :src_big ] 

          emb.add_field( name: "Изображение", value: p )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: p )
        when "video"
          p = attach[ :video ]

          emb.add_field( name: "Видео", value: "http://vk.com/video#{ g }_#{ p[ :vid ] }" )
          emb.add_field( name: "Название", value: p[ :title ] )
          emb.image = Discordrb::Webhooks::EmbedImage.new( url: p[ :image_big ] ) 
        when "doc"
          p = attach[ :doc ]

          emb.add_field( name: "Документ", value: p[ :url ] )
          emb.add_field( name: "Название", value: p[ :title ] )
        end
      end

      d[ 'servers' ].each do | serv |
        if @channels[ serv ].nil? or @channels[ serv ][ 'vk-news' ].nil? then next; end
        @bot.send_message( @channels[ serv ][ 'vk-news' ], '', false, emb )
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

      if @channels[ id ][ 'vk-news' ].nil? then
        e.respond "Отсутствует канал для новостей. Чтобы воспользоваться данной командой, создайте канал с названием 'vk-news'."
        return
      end

      if g.index( "-" ).nil? then
        e.respond "В самом начале ID группы пропущен '-'. Пожалуйста, не забудьте его в следующий раз."
        g = "-" + g
      end

      if @config[ 'groups' ][ g.to_s ].nil? then
        @config[ 'groups' ][ g.to_s ] = { 'id' => "", 'servers' => [] }
      end

      @config[ 'groups' ][ g.to_s ][ 'servers' ].push( id )
      @client.save_config

      e.respond "<@#{ e.user.id }>, ID группы #{ g } добавлен в список групп для новостей."
    end
  end
end