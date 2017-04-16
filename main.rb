require 'discordrb'
require 'json'
require 'httparty'

module DiscordBot
  class Main
    attr_accessor :bot, :channels, :config

    def initialize
      unless File.exists?( 'cfg.json' )
        File.open( 'cfg.json', 'w+' ) {|f| f.write( JSON.pretty_generate({ 
          'token' => '', 
          'id' => '',
          'prefix' => '!', 
          'owner' => 0,
          'wikies' => {},
          'groups' => {},
          'ignored' => []
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
        no_permission_message: "Недостаточно прав, чтобы выполнить действие."
      )
      @channels = {}
      @cfg_mutex = Mutex.new
      @error_log = Mutex.new
    end

    def start
      @bot.ready do | e |
        @bot.update_status( 'Discord Ruby', '!help or !get_help', nil )
        @bot.set_user_permission( @config[ 'owner' ], 3 )

        update_info
        register_modules
        ignore_users
      end
    
      @bot.message do | e |
        if e.channel.pm? and e.user.id != @config[ 'owner' ] then
          b = e.message.timestamp.to_s.gsub( /\s\+\d+$/, '' ) + " #{ e.user.name } [#{ e.user.id }]: "
          File.open( 'pm.log', 'a' ) { |f| f.write( b + e.message.content.split( "\n" ).join( "\n" + b ) + "\n" ) }
        end
      end

      @bot.channel_create do | e |
        if !e.channel.pm? then
          update_info
        end
      end

      @bot.channel_delete do | e |
        update_info
      end

      @bot.member_join do | e |
        if !@config[ 'exclude welcome' ].include?( e.server.id ) and can_do( e, :send_messages ) then
          e.server.general_channel.send_message "Добро пожаловать на сервер, <@#{ e.user.id }>. Пожалуйста, предоставьте ссылку на свой профиль в Фэндоме, чтобы администраторы могли добавить вас в группу."

          g = e.server.roles.find { |r| r.name == "Новички" }
          if !g.nil? and can_do( e, :manage_roles ) then
            e.user.add_role( g )
          end
        end
      end

      @bot.member_leave do | e |
        if !@config[ 'exclude welcome' ].include?( e.server.id ) and can_do( e, :send_messages ) then
          e.server.general_channel.send_message "#{ e.user.name } покинул сервер."
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

      @bot.run
    end

    def register_modules
      DiscordBot.constants.select do | c |
        if DiscordBot.const_get( c ).is_a? Class then
          if c.to_s == "Main" then
            next
          end

          m = DiscordBot.const_get( c ).new( self )

          if DiscordBot.const_get( c ).method_defined? "commands" then
            m.commands
          end
        end
      end
    end
    
    def update_info
      @bot.servers.each do |k, v|
        @channels[ k ] = {}
        v.roles.each do | arr, i |
          perm = arr.permissions
          @bot.set_role_permission( arr.id, ( perm.kick_members or perm.ban_members or perm.administrator or perm.manage_server ) ? 2 : 1 )
        end
        v.channels.each {| arr | @channels[ k ][ arr.name ] = arr.id }
      end
    end

    def can_do( e, type )
      return @bot.profile.on( e.server ).permission?( :send_messages, e.channel )
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
  end
end