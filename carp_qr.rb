#!/usr/bin/ruby

require 'rubygems'
gem 'twitter4r'
require 'twitter'
require 'mechanize'
require 'hpricot'
require 'pp'
require 'kconv'

USER = 'carp_qr'
PASS = 'higashide2'

def fileread
  if ( File.file? '/var/tmp/carp_qr' )
    File.open('/var/tmp/carp_qr'){|t|
      return eval(t.read)
    }
  end
end

def store_result(result)
  File.open('/var/tmp/carp_qr', 'w'){|f|
    $stdout = f
    pp result
    $stdout = STDOUT
  }
end

def which_win(team_list, score)
  hash = {
    team_list[0] => score.split(/-/)[0],
    team_list[1] => score.split(/-/)[1],
  }
  if (team_list[0] == "広島" and hash[team_list[0]] > hash[team_list[1]]) or
     (team_list[1] == "広島" and hash[team_list[1]] > hash[team_list[0]])
    return "勝ったよ!! .｡ﾟ+.(･∀･)ﾟ+.ﾟ"
  elsif (team_list[0] == "広島" and hash[team_list[0]] < hash[team_list[1]]) or
        (team_list[1] == "広島" and hash[team_list[1]] < hash[team_list[0]])
    return "ま、負けた・・ ｡･ﾟ･(ﾉД`)"
  else
    return "引き分け～"
  end
end

def record_f(today)
  File.open("/var/tmp/#{today}", 'w'){|f|
    $stdout = f
    puts 1
    $stdout = STDOUT
  }
end

def get_game_date(doc)
  game = (doc/"div.bord-card").inner_html.kconv(Kconv::UTF8, Kconv::EUC)
  ary = game.split(/\r\n\t/)
  date = ary[2].gsub(/ &nbsp;/, '').split(/\//)
  return sprintf("%02d-%02d-%02d", *date)
end

today = Date.today.to_s
exit if ( File.exist?("/var/tmp/#{today}") )

agent = WWW::Mechanize.new
agent.get('http://www.rcc.net/carp/')
agent.get('http://score.rcc.jp/')
agent.page.links[0].click
agent.get('http://score.rcc.jp/')

doc = Hpricot(agent.page.body)

team_list = []
(doc/"div.bord-team").each do |team|
  team_list << team.inner_html.kconv(Kconv::UTF8, Kconv::EUC)
end

result = []
(doc/"table.toku-waku tr").each do |tr|
  data = tr.inner_html.kconv(Kconv::UTF8, Kconv::EUC)
  next unless /width/ =~ data
  array = data.split(/\r\n\t/)
  tmp = {
    :when    => array[1].gsub(/<td width=\"\d+%\">/, '').gsub(/<\/td>/, '').gsub(/\s+/, '').strip,
    :who     => array[2].gsub(/<td width=\"\d+%\">/, '').gsub(/<\/td>/, '').strip,
    :content => array[3].gsub(/<td width=\"\d+%\">/, '').gsub(/<\/td>/, '').strip,
    :score   => array[4].gsub(/<td width=\"\d+%\">/, '').gsub(/<\/td>/, '').gsub(/\s+/, '').strip,
  }
  result << tmp
end
exit if result.empty? # 結果が取得できなかったら終了

content = fileread
client = Twitter::Client.new( :login => USER, :password => PASS )
(result - content).each do |d|
  client.status(:post, "【#{d[:when]}】【#{team_list[0]} #{d[:score]} #{team_list[1]}】#{d[:who]}が#{d[:content]}")
end

store_result(result)

if ( today == get_game_date(doc) )
  unless ( (doc/"span.pitcher-color").empty? )
    win = which_win(team_list, result[-1][:score])
    client.status(:post, "【試合終了】【#{team_list[0]} #{result[-1][:score]} #{team_list[1]}】#{win}")
    record_f(today)
  end
end

