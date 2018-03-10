module DiscordBot
  class Mafia
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels

      @mafia = {}
      for_init
    end

    def for_init
      @bot.servers.each do |k, v|
        @mafia[ k ] = { 'state' => false, 'running' => false }
      end
    end

    def commands
      @bot.command(
        :mafia,
        min_args: 1,
        description: "Взаимодействие с игрой Мафия.",
        usage: "Требуется указать значение on/off: !mafia on"
      ) do | e, s | mafia( e, s ) end

      @bot.command(
        :mafia_join,
        description: "Присоединиться к игре, оставив заявку на участие.",
        usage: "!mafia_join"
      ) do | e | mafia_join( e ) end

      @bot.command(
        :mafia_leave,
        description: "Отменить заявку на участие в игре.",
        usage: "!mafia_leave"
      ) do | e | mafia_leave( e ) end

      @bot.command(
        :mafia_vote,
        min_args: 1,
        description: "Команда для голосования жителей.",
        usage: "Требуется упомянуть игрока: !mafia_vote @kopcap94"
      ) do | e, v | mafia_vote( e, v ) end

      @bot.command(
        :mafia_kill,
        min_args: 2,
        description: "Команда для голосования мафии.",
        usage: "Требуется указать ID сервера и игрока: !mafia_kill <id сервера> <id игрок>. Пример: !mafia_kill 23232323 3332323."
      ) do | e, s, v | mafia_kill( e, s, v ) end
    end

    def mafia( e, state )
      if e.channel.pm? then return; end

      id = e.server.id
      if @mafia[ id ].nil? then @mafia[ id ] = { 'state' => false, 'running' => false } end

      s = @mafia[ id ][ 'state' ]

      if e.channel.pm? then
        e.respond "Сам с собой будешь играть?"
        return
      elsif @channels[ id ][ 'мафия' ].nil? then
        e.respond "Отсутствует канал для игры в мафию. Пожалуйста, создайте канал с названием mafia, чтобы запустить игру."
        return
      elsif s and state == "on" then
        e.respond "Мафия уже включена."
        return
      elsif !s and state == "off" then
        e.respond "Мафия на данный момент отключена. Нельзя отключить то, что уже отключено."
        return
      elsif s and state == "off" then
        @mafia[ id ][ 'state' ] = false
        e.respond "Игра отключена."
        return
      elsif !s and state == "on" then
        if @mafia[ id ][ 'running' ] then
          e.respond "На данный момент идёт игра. Включить игру снова невозможно."
          return
        end

        begin
          @mafia[ id ][ 'users' ] = {}
          @mafia[ id ][ 'state' ] = true

          mafia_time_thread( id )
          mafia_join( e )
        rescue => err
          @c.error_log( err, "MAFIA" )
        end

        e.respond "@here Начинается сбор заявок на участие в игре! Оставить заявку можно командой !mafia_join. Сбор заявок в течении 5 минут."
      end
    end

    def mafia_time_thread( id )
      Thread.new {
        4.downto( 1 ) do | i |
          sleep 60
          @bot.send_message( @channels[ id ][ 'мафия' ], "До завершения сбора заявок #{ i } #{ i == 1 ? "минута":"минуты" }" )
        end
        sleep 60
  
        if @mafia[ id ][ 'users' ].count < 4 then
          @bot.send_message( @channels[ id ][ 'мафия' ], "Игра отменена, мало участников." )
          @mafia[ id ][ 'state' ] = false
          return true
        end

        @bot.send_message( @channels[ id ][ 'мафия' ], "Начинается игра, рассылаю список ролей." )
        mafia_start_game( id )
      }
    end

    def mafia_join( e )
      if e.channel.pm? then
        e.respond "Вы не можете присоединиться к игре через личные сообщения. Используйте команду в чате того сервера, на котором запущена игра."
        return
      end

      u = e.user.id
      id = e.server.id

      if @mafia[ id ][ 'state' ] == false then
        e.user.pm "Игра \"Мафия\" отключена"
        return
      elsif @mafia[ id ][ 'running' ] then
        e.user.pm "Вы не можете присоединиться к игре, так как последняя уже запущена."
        return
      elsif !@mafia[ id ][ 'users' ][ u ].nil? then
        e.user.pm "Вы уже в списке."
        return
      end

      @mafia[ id ][ 'users' ][ u ] = e.user.name
      e.user.pm "Ваша заявка на участие принята. Чтобы отменить заявку, используйте команду !mafia_leave в чате того сервера, где подали заявку."
    end

    def mafia_leave( e )
      if e.channel.pm? then
        e.respond "Вы не можете покинуть игру через личные сообщения. Используйте команду в чате того сервера, на котором запущена игра."
        return
      end

      u = e.user.id
      id = e.server.id

      if !@mafia[ id ][ 'state' ] then
        return
      elsif @mafia[ id ][ 'users' ][ u ].nil? then
        e.user.pm "Вашей заявки не было в списке участников."
        return
      end

      @mafia[ id ][ 'users' ].delete( u )
      e.user.pm "Ваша заявка на участие снята."
    end

    def mafia_start_game( id )
      @mafia[ id ][ 'running' ] = true

      l = @mafia[ id ][ 'users' ].count
      mafia_counter = ( l >=4 and l <= 6 ) ? 1 : 2

      @mafia[ id ][ 'roles' ] = { :main => [], :second => [] }
      @mafia[ id ][ 'users' ].each {| k, u | @mafia[ id ][ 'roles' ][ :second ].push( k ) }

      mafia_counter.times do
        player = @mafia[ id ][ 'roles' ][ :second ].sample

        @mafia[ id ][ 'roles' ][ :second ].delete( player )
        @mafia[ id ][ 'roles' ][ :main ].push( player )
      end

      @mafia[ id ][ 'users' ].each do | i, k |
        u = @bot.users.find { | key, us | key == i }[ 1 ]
        u.pm "Ваша роль - #{ @mafia[ id ][ 'roles' ][ :main ].include?( i ) ? "Мафия. Используйте команду !mafia_kill с ID игрока, чтобы убить его. Пример: !mafia_kill #{ id } 23332132, где #{ id } - ID сервера" : "Мирный житель" }."

        if mafia_counter == 2 and @mafia[ id ][ 'roles' ][ :main ].include?( i ) then
          a = @mafia[ id ][ 'roles' ][ :main ].index( i ) == 0 ? 1 : 0 
          u.pm "Ваш напарник - <@#{ @mafia[ id ][ 'roles' ][ :main ][ a ] }>."
        end
      end

      mafia_night_thread( id )
    end

    def mafia_day_thread( id )
      Thread.new {
        @mafia[ id ][ 'night' ] = false
        @mafia[ id ][ 'sec_vote' ] = {}
        u = [ [], 0 ]

        @bot.send_message( @channels[ id ][ 'мафия' ], "Как бы то ни было, у жителей есть 4 минуты, чтобы найти преступников и убить их.\nИспользуйте команду !mafia_vote с упоминанием игрока, чтобы проголосовать за его убийство. Пример - !mafia_vote @kopcap" )
        sleep 240 # 4 минуты на размышление

        if @mafia[ id ][ 'sec_vote' ].count == 0 then
          @bot.send_message( @channels[ id ][ 'мафия' ], "Видимо, мирным жителям неинтересна инициатива голосования и выживания." )
          if @mafia[ id ][ 'running' ] then mafia_night_thread( id ) end
          return
        end

        @mafia[ id ][ 'sec_vote' ].each do | k, v |
          c = v.count

          if c > u[ 1 ] then
            u = [ [ k ], c ]
          elsif c == u[ 1 ] then
            u[ 0 ].push( k )
          end
        end

        if u[ 0 ].count != 1 then
          @bot.send_message( @channels[ id ][ 'мафия' ], "Мирные жители разошлись в мнении между <@#{ u[ 0 ].join( ">, <@" ) }>. Было принято решение вытянуть жребий." )
          u[ 0 ] = [ u[ 0 ].sample ]
          @bot.send_message( @channels[ id ][ 'мафия' ], "Короткий жребий достался <@#{ u[ 0 ][ 0 ] }>. Увы, но для него это конец." )
        end

        kill( u[ 0 ][ 0 ], 'day', id )
        if @mafia[ id ][ 'running' ] then mafia_night_thread( id ) end
      }
    end

    def mafia_night_thread( id )
      Thread.new {
        @bot.send_message( @channels[ id ][ 'мафия' ], "Наступает ночь. Мирные жители засыпают. Просыпается мафия. У мафии 1,5 минуты на принятие решений." )

        @mafia[ id ][ 'night' ] = true
        @mafia[ id ][ 'mafia_vote' ] = []
        @mafia[ id ][ 'target' ] = nil
        list = "__**ГОЛОСОВАНИЕ МАФИИ ПРОХОДИТ ТОЛЬКО ТУТ!**__\nТекущий мирных жителей:\n"

        @mafia[ id ][ 'roles' ][ :second ].each do | p |
          list = list + "ID: #{ p } [ #{ @mafia[ id ][ 'users' ][ p ] } ]\n"
        end

        list = list + "**ID сервера: #{ id }**.\nПредзаполненная команда **c ID сервера**, допишите только ID игрока:"

        @mafia[ id ][ 'roles' ][ :main ].each do | i |
          m = @bot.users.find { | k, us | k == i }[ 1 ]
          m.pm "#{ list }"
          m.pm "**!mafia_kill #{ id }**"
        end

        sleep 90 #1,5 минуты

        @bot.send_message( @channels[ id ][ 'мафия' ], "На горизонте задребезжал рассвет. Мирные жители проснулись." )

        if @mafia[ id ][ 'mafia_vote' ].count == 0 then
          k = @mafia[ id ][ 'roles' ][ :second ].sample

          @bot.send_message( @channels[ id ][ 'мафия' ], "Кажется, этой ночью мафия не смогла договориться и решила оставить мирных жителей в покое.\nОднако этот мир жесток. Ночью по естественным причинам умер <@#{ k }>." )
        else
          k = !@mafia[ id ][ 'target' ].nil? ? @mafia[ id ][ 'target' ] : @mafia[ id ][ 'mafia_vote' ].sample

          @bot.send_message( @channels[ id ][ 'мафия' ], "На улице было найдено тело <@#{ k }>. Следы пуль говорили о многом." )
        end

        kill( k, 'night', id )
        if @mafia[ id ][ 'running' ] then mafia_day_thread( id ) end
      }
    end

    def mafia_vote( e, v )
      if e.channel.pm? then
        e.respond "Вы не можете проголосовать в личных сообщениях. Делайте это на виду у всех участников."
        return
      end

      v = @c.parse( v )
      u = e.user.id
      id = e.server.id

      if @mafia[ id ].nil? or !@mafia[ id ][ 'running' ] then
        e.user.pm "Игра в данный момент не запущена."
        return
      elsif (!@mafia[ id ][ 'roles' ][ :main ].include?( u ) and !@mafia[ id ][ 'roles' ][ :second ].include?( u ) ) then
        return
      elsif v.nil? or v == "" then
        e.user.pm "Неправильно выбран участник. Попробуйте проголосовать снова."
        return
      elsif @mafia[ id ][ 'sec_vote' ][ v ].nil? then
        @mafia[ id ][ 'sec_vote' ][ v ] = []
      else # проверка, если уже голосовали
        @mafia[ id ][ 'sec_vote' ].each do | k, arr |
          if arr.include?( u ) then
            arr.delete( u )
          end
        end
      end

      @mafia[ id ][ 'sec_vote' ][ v ].push( u )
      e.user.pm "Выбор сделан."
    end

    def mafia_kill( e, id, v )
      v = @c.parse( v )
      id = @c.parse( id )

      if @mafia[ id ].nil? or !@mafia[ id ][ 'running' ] then
        e.user.pm "Неправильно указан id сервера или игра в данный момент не запущена."
        return
      elsif !@mafia[ id ][ 'night' ] then
        e.user.pm "Вы не можете голосовать днём."
        return
      elsif !@mafia[ id ][ 'roles' ][ :main ].include?( e.user.id ) then
        return
      elsif @mafia[ id ][ 'roles' ][ :main ].include?( v ) then 
        e.respond "Вы не можете убить своего напарника. Но мне нравится эта идея."
        return
      elsif !@mafia[ id ][ 'roles' ][ :second ].include?( v ) then
        e.respond "Игрока с таким ID нет. Пожалуйста, проверьте правильность ввода ID."
        return
      elsif @mafia[ id ][ 'mafia_vote' ].include?( v ) then
        @mafia[ id ][ 'target' ] = v
        return
      end

      @mafia[ id ][ 'mafia_vote' ].push( v )
      e.user.pm "Ваше решение принято."
    end

    def kill( u, t, id )
      case t
      when 'night'
        @mafia[ id ][ 'roles' ][ :second ].delete( u )
      when 'day'
        if @mafia[ id ][ 'roles' ][ :second ].include?( u ) then
          k = "мирным жителем"
          @mafia[ id ][ 'roles' ][ :second ].delete( u )
        else
          k = "мафией"
          @mafia[ id ][ 'roles' ][ :main ].delete( u )
        end

        @bot.send_message( @channels[ id ][ 'мафия' ], "Жители приняли решение убить <@#{ u }>. После вынесения приговора и убийства выяснилось, что он был **#{ k }**." )
      end

      m = @mafia[ id ][ 'roles' ][ :main ].count
      s = @mafia[ id ][ 'roles' ][ :second ].count

      if ( m == 1 and s < 2 ) or ( m == 2 and s < 3 ) then
        @bot.send_message( @channels[ id ][ 'мафия' ], "Сколько бы мирные жители не старались бороться с мафией, у них это не вышло. Невозможно представить, какой ужас испытали последние выжившие, встретившись один на один с мафией. К сожалению, их игра закончена." )
        @bot.send_message( @channels[ id ][ 'мафия' ], "Выжившая мафия: <@#{ @mafia[ id ][ 'roles' ][ :main ].join( "> <@!") }>" )

        @mafia[ id ] = { 'state' => false, 'running' => false }
        return
      elsif m == 0 then
        @mafia[ id ] = { 'state' => false, 'running' => false }

        @bot.send_message( @channels[ id ][ 'мафия' ], "С утра местный шериф, попивая кофе у себя дома, радостно улыбнётся, прочитав заголовок о полном провале мафии в этом городе. На этот раз игра для них закончена. Но конец ли это в общем?" )
        return
      end
    end
  end
end
