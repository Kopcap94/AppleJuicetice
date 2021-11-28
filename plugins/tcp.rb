
require 'socket'

module DiscordBot
  class TCPRelay
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
      @config = client.config
      @thr = client.thr
      @names = [ 'recentchanges', 'wiki-activity', 'правки', 'активность', 'вики-активность' ]
      @del_id = 0

      for_init
    end

    def for_init
      @thr[ 'tcp' ] = Thread.new {
        open_server
      }
    end

    def open_server
      s = TCPServer.open( 5445 )
      loop {
        t = Thread.start( s.accept ) do | c |
          data = c.gets.chomp

          begin
            d = JSON.parse( data )
            send_info( d )
          rescue JSON::ParserError
            puts "Ошибка при парсе #{ data }"
          rescue => err
            puts "А, ой"
          end

          c.close
          t.kill
        end
      }
    end

    def send_info( data )
      if data[ "action" ] == "deleted" and data[ "type" ] == "message-wall-thread"
        d_id = data[ "url" ].gsub( /.*threadId=(\d+)/, '\1' )
        return if d_id == @del_id

        @del_id = d_id
      end

      emb = Discordrb::Webhooks::Embed.new
      cat_name = "Категория"

      case data[ "action" ]
      when "deleted"
        action = "🗑️ • Удалено"
      when "created"
        action = "🗨️ • Создано"
      when "modified"
        action = "📝 • Отредактировано"
      when "moved"
        action = "📁 • Перемещено"
      when "un-delete"
        action = "🗃️ • Восстановлено"
      else
        action = data[ "action" ]
      end

      case data[ "type" ]
      when "discussion-thread"
        type = "Тема в общих обсуждениях"
        color = "#009DFF"
      when "discussion-post"
        type = "Ответ в теме в общих обсуждениях"
        color = "#28ABFF"
      when "discussion-report"
        type = "Жалоба на нарушение!"
        color = "#FF0000"
      when "message-wall-thread"
        type = "Тема на стене"
        color = "#009E60"
        cat_name = "У участника"
      when "message-wall-post"
        type = "Ответ в теме на стене"
        color = "#33B180"
        cat_name = "У участника"
      when "article-comment-thread"
        type = "Тема в обсуждениях статьи"
        color = "#FFA701"
      when "article-comment-reply"
        type = "Ответ в теме в обсуждениях статьи"
        color = "#FFFF33"
      else
        type = "Неопределённый тип действия: #{ data[ "type" ] }"
        color = "#000000"
      end

      user = data[ "userName" ] == "" ? "Аноним" : data[ "userName" ]
      title = data[ "title" ] == "" ? "-" : data[ "title" ]
      text = data[ "snippet" ] == "" ? "-" : data[ "snippet" ]
      category = data[ "category" ] == "" ? "-" : data[ "category" ].gsub( /\sMessage Wall/, '' )

      emb.color = color
      emb.author = Discordrb::Webhooks::EmbedAuthor.new( name: "[ #{ action } ] #{ type }", url: data[ "url" ] )
      emb.add_field( name: "Участник", value: user, inline: true )
      emb.add_field( name: cat_name, value: category, inline: true )
      emb.add_field( name: "Ссылка", value: "[Ссылка](#{ data[ "url" ] })", inline: true )
      emb.add_field( name: "Заголовок", value: title )
      emb.add_field( name: "Текст", value: text )

      @config[ "wikies" ][ data[ "wiki" ] ][ "servers" ].clone.each do | id |
        if @channels[ id ].nil? then next; end

        s_ch = @channels[ id ].keys
        channel = s_ch & @names

        if channel.empty? then next; end
        @bot.send_message( @channels[ id ][ channel[ 0 ] ], '', false, emb )
      end
    end
  end
end