require 'open-uri'

module DiscordBot
  class Voice
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
    end

    def commands
      @bot.command(
        :vjoin,
        min_args: 1,
        description: "",
        usage: ""
      ) do | e, *vс | join( e, vс.join( " " ).to_s ) end

      @bot.command(
        :vplay,
        min_args: 1,
        description: "Требует ссылку на .mp3 файл. Учтите, что ссылка должна быть прямой!",
        usage: "!vplay something.com/file.mp3"
      ) do | e, m | play( e, m ) end

      @bot.command(
        :vpause,
        description: "Ставит воспроизведение файла на паузу.",
        usage: "Не требует параметров."
      ) do | e | act( e, true ) end

      @bot.command(
        :vcon,
        description: "Продолжает воспроизведение файла.",
        usage: "Не требует параметров."
      ) do | e | act( e, false ) end

      @bot.command(
        :vstop,
        description: "Полностью останавливает воспроизведение файла.",
        usage: "Не требует параметров."
      ) do | e | act( e, true, true ) end

      @bot.command(
        :vvol,
        min_args: 1,
        description: "Устанавливает уровень громкости бота. Значение указывается в % и должно находится в диапазоне от 0 до 200.",
        usage: "!vvol 150"
     ) do | e, v | vol( e, v.to_f ) end
    end

    def join( e, vc )
      id = e.server.id

      if @channels[ id ][ vc ].nil? then
        e.respond "Неправильно указано название канала."
        return
      end

      vc_id = @channels[ id ][ vc ]
      @bot.voice_connect( vc_id )
      e.message.create_reaction "\u2611"
    end

    def play( e, m )
      m = URI.encode( m )
      @bot.voice( e.server.id ).play_io( open( URI.parse( m ) ) )
      @bot.voice( e.server.id ).stop_playing
      e.message.create_reaction "\u2611"
    end

    def act( e, s, t=false )
      id = e.server.id
      if @bot.voice( id ).nil? then return; end

      if ( s ) then
        if ( t ) then
          @bot.voice( id ).stop_playing
          e.message.create_reaction "\u2611"
        else
          @bot.voice( id ).pause
          e.respond "Воспроизведение поставлено на паузу."
        end
      else
        @bot.voice( id ).continue
        e.respond "Продолжаю воспроизведение."
      end
    end

    def vol( e, v )
      if v < 0 or v > 200 then
        e.respond "Неправильно указано значение. Громкость указывается в процентах и входить в диапазон от 0 до 200 включительно."
        return
      end

      @bot.voice( e.server.id ).volume = v / 100
      puts v / 100
      e.message.create_reaction "\u2611"
    end
  end
end