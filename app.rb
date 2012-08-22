class App < Sinatra::Base
  register Sinatra::Async
  
  COLLECTION = 'test'
  DB = 'em_benchmark'
  
  set :pooled_connection, Mongo::Connection.new('localhost', 27017, pool_size: 20, pool_timeout: 2)
  
  #EM.next_tick do
  #  EM.add_periodic_timer(0.5) { puts ">>> Hearbeat @ #{Time.now}" }
  #end
  
  helpers do
    def collection(conn)
      db = conn.db(DB)
      db.collection(COLLECTION)
    end
    
    def cursor(coll)
      coll.find
    end
  end
  
  # Clear the Mongo collection
  get '/clear' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    coll.remove
    
    conn.close
    
    'done'
  end
  
  # Insert one million documents in the Mongo collection
  get '/populate' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    1_000_000.times { coll.save(value: rand(1_000).hash) }

    conn.close

    'done'
  end
  
  # Create new blocking Mongo connection
  #
  # ab -n 200 -c 25 http://127.0.0.1:9292/test1
  #
  # Time taken for tests:   0.489 seconds
  # Requests per second:    409.27 [#/sec] (mean)
  #
  get '/test1' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    cur = cursor(coll)
    cur.count

    conn.close
    
    'done'
  end

  # Create new blocking Mongo connection and defer work to a thread
  #
  # ab -n 200 -c 25 http://127.0.0.1:9292/test2
  #
  # Time taken for tests:   0.345 seconds
  # Requests per second:    579.79 [#/sec] (mean)
  #
  aget '/test2' do
    conn = Mongo::Connection.new
    coll = collection(conn)
    op = proc do
      cur = cursor(coll)
      cur.count
    end
    cback = proc do
      conn.close
      body 'done'
    end
    EM.defer(op, cback)
  end

  # Check out Mongo connection from a connection pool and defer work to a thread
  #
  # ab -n 200 -c 25 http://127.0.0.1:9292/test3
  #
  # Time taken for tests:   0.251 seconds
  # Requests per second:    798.11 [#/sec] (mean)
  #
  aget '/test3' do
    coll = collection(settings.pooled_connection)
    op = proc do
      cur = cursor(coll)
      cur.count
    end
    cback = proc { body 'done' }
    EM.defer(op, cback)
  end

  # Create new non-blocking Mongo connection
  #
  # ab -n 200 -c 25 http://127.0.0.1:9292/test4
  #
  # Time taken for tests:   0.220 seconds
  # Requests per second:    910.52 [#/sec] (mean)
  #
  aget '/test4' do
    coll = collection(EM::Mongo::Connection.new)
    cur = cursor(coll)
    resp = cur.count
    resp.callback { body 'done' }
    resp.errback { |e| body e.message }
  end
  
  # TODO
  #  * test5: Test where checking out a non-blocking Mongo connection from a connection pool
  #  * test6: test4 wrapped in a fiber
  #  * test7: test5 wrapped in a fiber
end
