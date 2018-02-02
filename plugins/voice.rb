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
        description: "Пригласить бота в голосовой канал. Требуется указать название канала.",
        usage: "!vjoin VoiceChannel"
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
        :vvolume,
        min_args: 1,
        description: "Устанавливает уровень громкости бота. Значение указывается в % и должно находится в диапазоне от 0 до 200.",
        usage: "!vvolume 150"
      ) do | e, v | volume( e, v ) end

      @bot.command(
        :vdrop,
        description: "Отключает бота от голосового канала. Не требует параметров.",
        usage: "!vdrop"
      ) do | e | vdrop( e ) end
    end

    def join( e, vc )
      id = e.server.id

      if @channels[ id ][ vc ].nil? then
        e.respond "Неправильно указано название канала."
        return
      end

      vc_id = @channels[ id ][ vc ]
      @bot.voice_connect( vc_id )
      e.respond "Подключился к #{ vc }!"
    end

    def play( e, m )
      m = URI.encode( m )
      id = e.server.id

      if !in_voice( e ) then return; end

      @bot.voice( e.server.id ).stop_playing #yolo
      @bot.voice( id ).play_io( open( URI.parse( m ) ) )
      @bot.voice( e.server.id ).stop_playing
    end

    def act( e, s, t=false )
      id = e.server.id

      if !in_voice( e ) then return; end

      if ( s ) then
        if ( t ) then
          @bot.voice( e.server.id ).stop_playing
          e.respond "Воспроизведение остановлено."
        else
          @bot.voice( id ).pause
          e.respond "Воспроизведение поставлено на паузу."
        end
      else
        @bot.voice( id ).continue
        e.respond "Продолжаю воспроизведение."
      end
    end

    def volume( e, v )
      if !in_voice( e ) then return; end
      v = v.to_f / 100

      if v < 0 or v > 2 then
        e.respond "Неправильно указано значение. Громкость указывается в процентах и должна находиться в диапазоне от 0 до 200 включительно."
        return
      end

      @bot.voice( e.server.id ).volume = v
      e.respond "Громкость: #{ v*100 }%"
    end

    def vdrop( e )
      if !in_voice( e ) then return; end

      @bot.voice( e.server.id ).destroy
      e.respond "Отключился от голосового канала."
    end

    def in_voice( e )
      if @bot.voice( e.server.id ).nil? then
        e.respond "На данный момент бот не находится в голосовом канале. Используйте команду !vjoin."
        return false
      else
        return true
      end
    end
  end
end