require 'rubygems'
require 'rss'
require 'open-uri'
require 'set'
require 'curb'
require 'rb-inotify'
require "rexml/document"
require "socket"
include REXML

$stdout = File.new('/app/nexus_logs/FS_Monitor.out', 'w')
$stdout.sync = true


class MonitorFSEvents

	attr_accessor :fsRoots, :notifier

	# initialize class file system root to watch and skip scenarios
	def initialize(notifier, fsRoots)
		@fsRoots=fsRoots
		@notifier=notifier
    end


	 # start recursive watch on repositories. watch for event delete and moved_to
    def startWatch()
    	self.fsRoots.each do |root|
	    		addWatch(root)
	    	end
		runWatch()
	end

	
	def addWatch(root)
		puts Time.now.to_s + " Watch Directory: #{root}"
		begin
			self.notifier.watch(root, :recursive, :moved_to, :mask_add) do |event|
				eventAction(event) 
			end
		rescue Exception => e  
			puts Time.now.to_s + " Exception Occured: in add watch. skip path #{root} " + "msg: " + e.message + e.backtrace.inspect
		end
	end


	def updateWatch(newPaths)
		puts Time.now.to_s + " Stop Notifier"
		retries = 3
		begin
			self.notifier.stop
		rescue Exception => e  
			puts Time.now.to_s + " Exception Occured: in UpdateWatch -> notifier.stop " + "msg: " + e.message + e.backtrace.inspect
			if retries > 0
		       puts "\tTrying #{retries} more times to stop notifier \n"
		       retries -= 1
		       sleep 10
		       retry
			else
				puts " all 3 attempts failed to stop notifier"
				raise Time.now.to_s + " Exception Occured: Unable to stop notifier successfully"
			end
		end
		sleep 10
		newPaths.each do |path|
			puts Time.now.to_s + " Add New Watch Directory: #{path}"
			addWatch(path)
		end
		runWatch()
	end


	def runWatch()
		puts Time.now.to_s + " Start notifier"
		begin
			self.notifier.run
		rescue Exception => e  
			puts Time.now.to_s + " Exception Occured: in notifier.run " + e.to_s + "msg: " + e.message + e.backtrace.inspect
			raise Time.now.to_s + " Exception Occured: Unable to start notifier successfully"
		end
	end


	# actions to perform When an event occours. Should be overriden from child class for more functionality
	def eventAction (event)
		#puts Time.now.to_s + " Event Occured: #{event.flags} for file #{event.absolute_name}"
	end

	# to fetch IP address of the current machine
	def getIP
  		Socket.ip_address_list.detect{|intf| intf.ipv4_private?}
	end


    # execute rsync from active cluster to back up cluster storage using user=app. skip rsync on backup cluster
	def processRsync(eventName, destList, destRoot, user)
		puts Time.now.to_s + " ********start rsync*********"
		src=eventName

		destList.each do |server| 
			dest=user+'@'+server+':'+destRoot
			rsyncCmd="rsync -avR #{src} #{dest}"
			puts Time.now.to_s + " rsync:  #{src} #{dest}"
			begin
				result= `#{rsyncCmd}`
				puts Time.now.to_s + " result #{result}"

			rescue Exception => e  
				puts Time.now.to_s + " Exception Occured: in #{rsyncCmd} " + "msg: " + e.message + e.backtrace.inspect
  			end

		end

	end


	# Call Nexus APIs for Indexing and Meta data updates
	def processApiRequest(pathArr, servers, port, nexusEn, action)

		resData=""
		resCode=""
		retries = 3
		c = Curl::Easy.new
		c.http_auth_types = :basic
	  	headers={}
		headers['Authorization']=nexusEn
		c.headers=headers
		if action.eql? "delete"
	  		c.delete = true
	  		puts Time.now.to_s + " perform delete operation"
	  	elsif action.eql? "get"
	  		puts Time.now.to_s + " perform fetch operation"
	  	else
	  		puts Time.now.to_s + " action not supported : #{action}"
	  	end

	  	servers.each do |server|
			pathArr.each do |path|
				url = "http://" + server + ":" + port + path
				puts Time.now.to_s + " ********Api Request: #{url}"
				c.url = url
				begin
	    			c.perform
	    			resData=resData+c.body_str
	    			resCode=c.response_code.to_s
	    			puts Time.now.to_s + "********Api Response: #{resCode}"
					if ( !resCode.eql?("200") && !resCode.eql?("204"))
						raise "Exception Occoured: API request failed"
					else
						puts Time.now.to_s + " ********Api Result: SUCCESS"
					end
				
	    		rescue => e
					puts Time.now.to_s + "msg: " + e.message + e.backtrace.inspect
  					if retries > 0
				      puts "\tTrying #{retries} more times to call the api to #{server} #{path}\n"
				      retries -= 1
				      sleep 2
				      retry
				    else
       					puts " #{action} api call (all 3 attempts) failed for #{server} #{path}"
					end
				end
	    	end
		end
	resData
	end

end




class NexusEventManager < MonitorFSEvents

	attr_accessor :nexus_notifier,:fsRoots,:currentCluster,:backupNFS

	# constants
	ROOT = "/"
	USER = "app"
	STORAGE_PATH = '/app/nexus/sonatype-work/nexus/storage/'
	NEXUS_CONF_PATH = '/app/nexus/sonatype-work/nexus/conf/'


	# initialize class file system root to watch and skip scenarios
	def initialize(nexus_notifier, fsRoot, currentCluster, backupNFS)
		super(nexus_notifier,fsRoot)
		@currentCluster=currentCluster
		@backupNFS=backupNFS
    end

    def startWatch()

    	puts Time.now.to_s + " parse xml to get list of files paths to watch"

    	repos = getHostedRepoPaths()
    	if (repos.length>0 && @fsRoots.length<repos.length)
    		@fsRoots=repos
    	end
	
		super		    	
		
	end

	# process valid events
    # 1. ignore directory creation
    # 2. ignore nexus tmp files created to process new deployments
    # 3. process all other files events
	def eventAction(event) 
		super
		processEventFlag=false

		if !event.flags.any? { |x| x.to_s == 'isdir' }
		then
			# commented to reduce logging. Can be added to Debug level after logger integration
			#puts Time.now.to_s + "ignore event triggered for Dir"
			processEventFlag=true
		end

		if processEventFlag
			puts Time.now.to_s + " Event Occured: #{event.flags} for file #{event.absolute_name}"
			executeAction(event.absolute_name)
		end

	end



	def getHostedRepoPaths()

		hostedRepos = Array.new

		if File.exists?(NEXUS_CONF_PATH + "nexus.xml")
			puts " read file "
			begin

				repof = File.new(NEXUS_CONF_PATH + "nexus.xml")
				doc = REXML::Document.new repof
					XPath.each( doc, "/nexusConfiguration/repositories/repository[writePolicy != 'READ_ONLY']/id" ) do |r|
							path = STORAGE_PATH + r.text + "/"
							puts "repo : #{path}"
							hostedRepos.push(path)
					end
			rescue Exception => e
                    puts Time.now.to_s + " Exception Occured: Unable to parse nexus.xml " + "msg: " + e.message + e.backtrace.inspect
                end
		else
			puts Time.now.to_s + " NO hosted repos found"
		end
		hostedRepos
	end


	# process valid events
	# 1. Artifacts files - run indexing on active cluster and rsync file to back up cluster storage
	# 2. etadata.xml, sha1, md5 - No indexing, rsync to backup cluster
	def executeAction(eventName)

		self.backupNFS.each do |ip|
		    	processRsync(eventName, [ip], ROOT, USER)
		end

	end


end

NexusEventManager.new(INotify::Notifier.new, ["/app/nexus/sonatype-work/nexus/storage/snapshots/"],["10.65.200.180","10.65.200.181"],["10.242.227.164","10.242.227.165"]).startWatch

