require 'discordrb'
require 'json'
require 'httparty'

module DiscordBot
  class Main
    attr_accessor :bot, :channels, :config, :thr

    Discordrb::LOGGER = Discordrb::Logger.new(false, [File.open('dbg_aj.txt', 'a+')])

    def initialize
      unless File.exists?( 'cfg.json' )
        File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate({ 
          'token' => '', 
          'id' => '',
          'prefix' => '!', 
          'owner' => 0,
          'wikies' => {},
          'groups' => { 'access_token' => '' },
          'ignored' => [],
          'blacklisted' => [],
          'exclude welcome' => []
        }))}
        puts "Создан новый конфиг, заполните его."
      end

      @config = JSON.parse( File.read( 'cfg.json' ) )
      @bot = Discordrb::Commands::CommandBot.new( 
        token: @config[ 'token' ],
        client_id: @config[ 'id' ],
        prefix: @config[ 'prefix' ],
        help_command: false,
        ignore_bots: true,
        log_mode: :debug,
        intents: [
          :servers,
          :server_members,
          :server_bans,
          :server_emojis,
          :server_webhooks,
          :server_messages,
          :server_message_reactions,
          :direct_messages
        ],
        no_permission_message: "Недостаточно прав, чтобы выполнить действие."
      )
      @channels = {}
      @thr = {}
      @cfg_mutex = Mutex.new
      @error_log = Mutex.new
      @started = false
    end

    def start
      @bot.ready do | e |
        puts "Ready!"
        @bot.set_user_permission( @config[ 'owner' ], 3 )

        update_info

        if !@started then
          ignore_users
          register_modules
          GC.start(full_mark: true, immediate_sweep: true)

          @started = true
        end

        @bot.update_status( 'Discord Ruby', '!help/!get_help', nil )
      end

      @bot.pm do | e |
        if e.user.id != @config[ 'owner' ] then
          b = e.message.timestamp.to_s.gsub( /\s\+\d+$/, '' ) + " #{ e.user.name } [#{ e.user.id }]: "
          File.open( 'pm.log', 'a' ) { |f| f.write( b + e.message.content.split( "\n" ).join( "\n" + b ) + "\n" ) }
        end
      end

      @bot.server_create do | e |
        s = e.server
        c = e.server.general_channel

        if @config[ 'blacklisted' ].include?( s.id ) then
          c.send_message "Ваш сервер занесён в чёрный список. Я не буду здесь находиться."
          s.leave
          next
        end
      end

      @bot.member_join do | e |
        s = e.server
        c = e.server.general_channel

        next if c.nil?

        if !@config[ 'exclude welcome' ].include?( s.id ) and can_do( s, 'send_messages', c ) then
          c.send_message "Добро пожаловать на сервер, <@#{ e.user.id }>. Пожалуйста, ознакомьтесь с правилами данного дискорд-сервера."
        end
      end

      @bot.member_leave do | e |
        next unless @bot.profile.id != e.user.id

        s = e.server
        c = e.server.general_channel

        next if c.nil?

        if !@config[ 'exclude welcome' ].include?( s.id ) and can_do( s, 'send_messages', c ) then
          c.send_message "#{ e.user.name } покинул сервер."
        end
      end

      @bot.mention do | e |
        a = [
          "чего?",
          "допустим.",
          "я здесь.",
          "спасибо, что связались с нами. Оставайтесь на линии, с вами никто не свяжется.",
          "тест успешно пройдён. Возьмите с полки пирожок. Их там два - крайние не трогайте.",
          "у меня, между прочим, есть список команд. Но я вам его не отдам. Вы ввели не ту команду.",
          "зачем вы абузите эту команду?",
          "ваши документы, пожалуйста.",
          "поздравляю. Вы только что пожертвовали пару секунд своей жизни. Спасибо за крайне не выгодное вложение!",
          "обернись!",
          "behind you!",
          "вы просите меня выполнять ваши команды. Но вы даже не говорите пожалуйста...",
          "прекращай.",
          "ну ещё пять минуточек...",
          "почему? Во имя чего? Зачем, зачем Вы используете эту команду? Зачем продолжаете делать это? Неужели Вы верите в какую-то миссию или Вам просто интересно? Так в чем же миссия, может быть Вы откроете? Это развлечение, интерес или Вы скучаете? Хрупкие логические теории человека, который отчаянно пытается оправдать свои действия: бесцельные и бессмысленные. Почему, #{ e.user.name }, почему Вы упорствуете?"
        ]
        e.respond "<@#{ e.user.id }>, #{ a.sample }"
      end

      @bot.raw do | e |
        update_info
        ev = @bot.servers[285482504817868800]

        next if ev.nil?
        if ev.channels.count == 0 then
          Discordrb::LOGGER.info("[TRACKER] GOT ZERO CHANNELS, GG")
          @bot.stop
        end
      end

      @bot.run
    end

    def register_modules
      Thread.new {
        DiscordBot.constants.select do | c |
          if DiscordBot.const_get( c ).is_a? Class then
            next if c.to_s == "Main"

            m = DiscordBot.const_get( c ).new( self )

            m.commands if DiscordBot.const_get( c ).method_defined? "commands"
          end
        end
      }
    end

    def update_info
      @bot.servers.each do | k, v |
        @channels[ k ] = {}
        v.roles.each do | arr, i |
          perm = arr.permissions
          @bot.set_role_permission( arr.id, ( perm.kick_members or perm.ban_members or perm.administrator or perm.manage_server ) ? 2 : 1 )
        end
        v.channels.each {| arr | @channels[ k ][ arr.name ] = arr.id }
      end
    end

    def can_do( s, t, c = nil )
      return @bot.profile.on( s ).permission?( t.to_sym, c )
    end

    def ignore_users
      return if @config[ 'ignored' ].count == 0

      @config[ 'ignored' ].each do | u |
        @bot.ignore_user( u )
      end
    end

    def save_config
      @cfg_mutex.synchronize do
        File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate( @config ) ) }
      end
    end

    def error_log( err, m )
      @error_log.synchronize do
        puts "New error for #{ m } on errors log."
        s = "[#{ m }] #{ err }:\n#{ err.backtrace.join( "\n" ) }\n#{ "=" * 10 }\n"
        File.open( 'error.log', 'a' ) {|f| f.write( s ) }
      end
    end

    def parse( i )
      return i.gsub( /[^\d]+/, '' ).to_i
    end
  end
end
