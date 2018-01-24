require 'socket'

module DiscordBot
  class TCPRelay
    def initialize( client )
      @c = client
      @bot = client.bot
      @channels = client.channels
      @thr = client.thr

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
          msg = c.gets.chomp.to_s.force_encoding( 'UTF-8' )
 
          channel = @channels[ 285482504817868800 ][ 'ponyville' ]

          begin
            @bot.send_message( channel, msg )
          rescue => err
            puts err.inspect
          end

          c.close
          t.kill
        end
      }
    end
  end
end