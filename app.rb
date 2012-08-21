class App < Sinatra::Base
  register Sinatra::Async
  
  COLLECTION = 'test'
  DB = 'em_benchmark'
  # SLOW_QUERY_TIME = 1*1000
  # SLOW_QUERY = "function() { var d = new Date((new Date()).getTime() + #{SLOW_QUERY_TIME}); while (d > (new Date())) { }; return true; }"
  
  set :pooled_connection, Mongo::Connection.new('localhost', 27017, pool_size: 10, pool_timeout: 2)
  EM.next_tick do
    EM.add_periodic_timer(0.5) { puts ">>> Hearbeat @ #{Time.now}" }
  end
  
  helpers do
    def collection(conn)
      #puts ">>> conn: #{conn.object_id}"
      db = conn.db(DB)
      coll = db.collection(COLLECTION)
    end
    
    # def init_data(coll)
    #   doc = {_id: 123, foo: :bar}
    #   coll.save(doc)
    # end

    def slow_query_cursor(coll)
      # init_data(coll)
      
      coll.find('$where' => {value: rand(1_000).hash})
    end
  end
  
  get '/clear' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    coll.remove
    
    conn.close
    
    'done'
  end
  
  get '/populate' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    1_000_000.times { coll.save(value: rand(1_000).hash) }

    conn.close

    'done'
  end
  
  get '/test1' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    cur = slow_query_cursor(coll)
    cur.count

    conn.close
    
    'done'
  end

  aget '/test2' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    op = proc do
      cur = slow_query_cursor(coll)
      cur.count
    end
    cback = proc do
      conn.close
      body 'done'
    end
    EM.defer(op, cback)
  end

  aget '/test3' do
    coll = collection(settings.pooled_connection)
    op = proc do
      cur = slow_query_cursor(coll)
      cur.count
    end
    cback = proc { body 'done' }
    EM.defer(op, cback)
  end

  aget '/test4' do
    coll = collection(EM::Mongo::Connection.new)
    cur = slow_query_cursor(coll)
    resp = cur.count
    resp.callback { body 'done' }
    resp.errback { |e| body e.message }
  end
  
  # get '/test5' do
  #   sleep(1)
  #   'done'
  # end
  # 
  # aget '/test6' do
  #   op = proc { sleep(1) }
  #   cback = proc { body 'done' }
  #   EM.defer(op, cback)
  # end
end
