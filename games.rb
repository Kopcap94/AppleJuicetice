module DiscordBot
	module Games
	  class Games
		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config

			@mafia_game_state = false
			@mafia_is_running = false
		end

		def mafia( e, state )
			if @mafia_game_state == true and state == "on" then
				e.respond "Мафия уже включена."
			elsif @mafia_game_state == false and state == "off" then
				e.respond "Мафия на данный момент отключена. Нельзя отключить то, что уже отключено."
			elsif @mafia_game_state == true and state == "off" then
				@mafia_game_state = false
				e.respond "Игра отключена."
			elsif @mafia_game_state == false and state == "on" then
				if @mafia_is_running then
					e.respond "На данный момент идёт игра. Включить игру снова невозможно."
					return
				end

				@mafia_users = {}
				@mafia_game_state = true

				mafia_time_thread
				mafia_join( e )

				e.respond "@here Начинается сбор заявок на участие в игре! Оставить заявку можно комнадой !mafia_join. Сбор заявок в течении 5 минут."
			end
		end

		def mafia_time_thread
			Thread.new {
				4.downto( 1 ) do | i |
					sleep 60
					@bot.send_message( @channels[ 'mafia' ], "До завершения сбора заявок: #{ i } #{ i == 1 ? "минута":"минуты" }" )
				end
				sleep 60
	
				if @mafia_users.count < 4 then
					@bot.send_message( @channels[ 'mafia' ], "Игра отменена, мало участников: #{ @mafia_users.count } < 4." )
					@mafia_game_state = false
					return true
				end

				@bot.send_message( @channels[ 'mafia' ], "Начинается игра, рассылаю список ролей." )
				mafia_start_game
			}
		end

		def mafia_join( e )
			u = e.user.id

			if @mafia_game_state == false then
				e.user.pm "Игра \"Мафия\" отключена"
				return
			elsif @mafia_is_running == true then
				e.user.pm "Вы не можете присоединиться к игре, так как последняя уже запущена."
				return
			elsif !@mafia_users[ u ].nil? then
				e.user.pm "Вы уже в списке."
				return
			end

			@mafia_users[ u ] = e.user.name
			e.user.pm "Ваша заявка на участие принята. Чтобы отменить заявку, используйте команду !mafia_leave."
		end

		def mafia_leave( e )
			u = e.user.id

			if @mafia_users[ u ].nil? then
				e.user.pm "Вашей заявки не было в списке участников."
				return
			end

			@mafia_users.delete( u )
			e.user.pm "Ваша заявка на участие снята."
		end

		def mafia_start_game
			@mafia_is_running = true

			l = @mafia_users.count
			mafia_counter = ( l >=4 and l <= 6 ) ? 1 : 2

			@mafia_roles = { :main => [], :second => [] }
			@mafia_users.each {| k, u | @mafia_roles[ :second ].push( k ) }

			mafia_counter.times do
				player = @mafia_roles[ :second ].sample

				@mafia_roles[ :second ].delete( player )
				@mafia_roles[ :main ].push( player )
			end

			@mafia_users.each do | id, k |
				u = @bot.users.find { | key, us | key == id }[ 1 ]
				u.pm "Ваша роль - #{ @mafia_roles[ :main ].include?( id ) ? "Мафия. Используйте команду !mafia_kill с ID игрока, чтобы убить его. Пример: !mafia_kill 23332132" : "Мирный житель" }."

				if mafia_counter == 2 and @mafia_roles[ :main ].include?( id ) then
					i = @mafia_roles[ :main ].index( id ) == 0 ? 1 : 0 
					u.pm "Ваш напарник - <@#{ @mafia_roles[ :main ][ i ] }>."
				end
			end

			mafia_night_thread
		end

		def mafia_day_thread
			Thread.new {
				@mafia_sec_vote = {}
				u = [ [], 0 ]

				@bot.send_message( @channels[ 'mafia' ], "Как бы то ни было, у жителей есть 4 минуты, чтобы найти преступников и убить их.\nИспользуйте команду !mafia_vote с упоминанием игрока, чтобы проголосовать за его убийство. Пример - !mafia_vote @kopcap" )
				sleep 240 # 4 минуты на размышление

				@mafia_sec_vote.each do | k, v |
					c = v.count

					if c > u[ 1 ] then
						u = [ [ k ], c ]
					elsif c == u[ 1 ] then
						u[ 0 ].push( k )
					end
				end

				if u[ 0 ].count != 1 then
					@bot.send_message( @channels[ 'mafia' ], "Мирные жители разошлись в мнении между <@#{ u[ 0 ].join( ">, <@" ) }>. Было принято решение вытянуть жребий." )
					u[ 0 ] = [ u[ 0 ].sample ]
					@bot.send_message( @channels[ 'mafia' ], "Короткий жребий достался <@#{ u[ 0 ][ 0 ] }>. Увы, но для него это конец." )
				end

				kill( u[ 0 ][ 0 ], 'day' )
				if @mafia_is_running then mafia_night_thread end
			}
		end

		def mafia_night_thread
			Thread.new {
				@bot.send_message( @channels[ 'mafia' ], "Наступает ночь. Мирные жители засыпают. Просыпается мафия. У мафии 1,5 минуты на принятие решений." )

				@mafia_vote = []
				@mafia_target = nil
				list = "Текущий мирных жителей:\n"

				@mafia_roles[ :second ].each do | p |
					list = list + "ID: #{ p } [ #{ @mafia_users[ p ] } ]\n"
				end

				@mafia_roles[ :main ].each do | id |
					m = @bot.users.find { | k, us | k == id }[ 1 ]
					m.pm "#{ list }"
				end

				sleep 90 #1,5 минуты

				@bot.send_message( @channels[ 'mafia' ], "На горизонте задребезжал рассвет. Мирные жители проснулись." )

				if @mafia_vote.count == 0 then
					k = @mafia_roles[ :second ].sample

					@bot.send_message( @channels[ 'mafia' ], "Кажется, этой ночью мафия не смогла договориться и решила оставить мирных жителей в покое.\nОднако этот мир жесток. Ночью по естественным причинам умер <@#{ k }>." )
				else
					k = !@mafia_target.nil? ? @mafia_target : @mafia_vote.sample

					@bot.send_message( @channels[ 'mafia' ], "На улице было найдено тело <@#{ k }>. Следы пуль говорили о многом." )
				end

				kill( k, 'night' )
				if @mafia_is_running then mafia_day_thread end
			}
		end

		def mafia_vote( e, v )
			v = parse( v )
			u = e.user.id

			if (!@mafia_roles[ :main ].include?( u ) and !@mafia_roles[ :second ].include?( u ) ) or !@mafia_is_running then
				return
			elsif v.nil? or v == "" then
				e.user.pm "Неправильно выбран участник. Попробуйте проголосовать снова."
				return
			elsif @mafia_sec_vote[ v ].nil? then
				@mafia_sec_vote[ v ] = []
			else # проверка, если уже голосовали
				@mafia_sec_vote.each do | k, arr |
					if arr.include?( u ) then
						arr.delete( u )
					end
				end
			end

			@mafia_sec_vote[ v ].push( u )
			e.user.pm "Выбор сделан."
		end

		def mafia_kill( e, v )
			v = parse( v )

			if !@mafia_roles[ :main ].include?( e.user.id ) or !@mafia_is_running then
				return
			elsif @mafia_roles[ :main ].include?( v ) then 
				e.respond "Вы не можете убить своего напарника. Но мне нравится эта идея."
				return
			elsif @mafia_vote.include?( v ) then
				@mafia_target = v
				return
			end

			@mafia_vote.push( v )
			e.user.pm "Ваше решение принято."
		end

		def kill( u, t )
			case t
			when 'night'
				@mafia_roles[ :second ].delete( u )
			when 'day'
				if @mafia_roles[ :second ].include?( u ) then
					k = "Мирный житель"
					@mafia_roles[ :second ].delete( u )
				else
					k = "Мафия"
					@mafia_roles[ :main ].delete( u )
				end

				@bot.send_message( @channels[ 'mafia' ], "Жители приняли решение убить <@#{ u }>. После вынесения приговора и убийство выяснилось, что он был #{ k }." )
			end

			m = @mafia_roles[ :main ].count
			s = @mafia_roles[ :second ].count

			if 
				( m == 1 and s == 1 ) or ( m == 2 and s < 3 )
			then
				@mafia_game_state = false
				@mafia_is_running = false

				@bot.send_message( @channels[ 'mafia' ], "Сколько бы мирные жители не старались бороться с мафией, у них это не вышло. Невозможно представить, какой ужас испытали последние выжившие, встретившись один на один с мафией. К сожалению, их игра закончена." )
				@bot.send_message( @channels[ 'mafia' ], "Выжившая мафия: <@#{ @mafia_roles[ :main ].join( "> <@!") }>" )
				return
			elsif m == 0 then
				@mafia_game_state = false
				@mafia_is_running = false

				@bot.send_message( @channels[ 'mafia' ], "С утра местный шериф, попивая кофе у себя дома, радостно улыбнётся, прочитав заголовок о полном провале мафии в этом городе. На этот раз игра для них закончена. Но конец ли это в общем?" )
				return
			end
		end

		def parse( t )
			return t.gsub( /[^0-9]/, '' ).to_i
		end
	  end
	end
end