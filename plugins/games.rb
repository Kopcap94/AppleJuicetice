module DiscordBot
  class Games
    def initialize( client )
      @c = client
      @bot = client.bot
    end

    def commands
      @bot.command(
        :число,
        min_args: 1,
        description: "Попробуйте отгадать число от 1 до 10.",
        usage: "Требуется указать число от 1 до 10: !число 10"
      ) do | e, i | luck( e, i ) end

      @bot.command(
        :рулетка,
        min_args: 1,
        description: "Русская рулетка. Кол-во патронов варьируется от 1 до 5.",
        usage: "Требуется указать число от 1 до 5: !рулетка 5"
      ) do | e, i | ruletka( e, i ) end

      @bot.command(
        :кнб,
        description: "Камень, ножницы, бумага. Не требует ввода аргументов.",
        usage: "Не требует параметров."
      ) do | e | knb( e ) end
    end

    def luck( e, i )
      i = @c.parse( i )
      u = "<@#{ e.user.id }>"

      if i == 0 or ( i < 1 or i > 10 ) then
        e.respond "#{ u }, вы точно ввели число и точно из заданного диапазона?"
        return
      end

      r = [*1..10].sample
      msg = ( r == i ) ? "мои поздравления, вы угадали." : "увы, но это не моё число."
      e.respond "#{ u }, #{ msg }"
    end

    def ruletka( e, i )
      i = @c.parse( i )
      u = "<@#{ e.user.id }>"

      if i == 0 then
        e.respond "#{ u }, а чем стрелять будем?"
        return
      elsif i == 6 then
        e.respond "#{ u }, я только заряжаю полную обойму, но уже точно знаю, что ты труп."
        sleep 1
        e.respond "*#{ e.user.name } убит*"
        return
      elsif i < 0 or ( 6 - i ) < 0 then
        e.respond "#{ u }, неверно выбрано число."
        return
      end

      r = [*1..6].sample
      s = [*1..6].take( 6 - i )

      e.respond "#{ u }, Вам #{ ( s.include? r ) ? "повезло, вы выжили." : "не повезло, вы были убиты." }"
    end

    def knb( e )
      id = "<@#{ e.user.id }>"
      u = [*0..2].sample
      b = [*0..2].sample
      a = [ 'Камень', 'Ножницы', 'Бумага' ]

      if u == b then
        e.respond "У меня *#{ a[ b ] }*, а что там у тебя? *#{ a[ u ] }*? Ух ты, ничья!"
      elsif ( u < b and ( 0..1 ) === u and ( 1..2 ) === b ) or ( u == 2 and b == 0 ) then
        e.respond "У меня *#{ a[ b ] }*, а у тебя *#{ a[ u ] }*... Твоя победа."
      else
        e.respond "У меня *#{ a[ b ] }*. У тебя там... *#{ a[ u ] }*? Пфф, я победил."
      end
    end
  end
end