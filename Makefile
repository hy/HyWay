

# Assumes mongo access params are in local ENV
#   under both ENV var conventions, new + old


MAIN = TheApp.rb Gemfile Gemfile.lock 
VIEWS = views/list.erb

SERVER = http://serene-forest-4377.herokuapp.com/

MONGOPATH = ~/mongodb-osx-x86_64-2.6.1/bin

AUDIO = ~/Dropbox/HyWay/static/VascularContent/Audio
IMAGES = ~/Dropbox/HyWay/static/VascularContent/Images
VIDEO = ~/Dropbox/HyWay/static/VascularContent/Video
METADATA = ~/Dropbox/HyWay/static/VascularContent/metadata.json
CONTENT_MSG = "TRY: Commit a Content / Metadata update"


###################### Begin Generic git Interactions #####################

known:
	clear
	git status

diff:
	clear
	git diff $(MAIN)

aware:
	heroku logs -t

a:
	echo $(CONTENT_MSG)
	/bin/date

rollback:
	git reset --soft HEAD~1


##################### Begin Aux/Mongo Interactions ###################

# http://www.gitguys.com/how-to-remove-a-file-from-git-source-control-but-not-delete-it/


connection:
	$(MONGOPATH)/mongo $(MONGO_URL):$(MONGO_PORT)/latest -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD)

task:
	curl -G -v  $(SERVER)log_at_asana --data-urlencode "m=$(m)"


##################### Begin Fundamental/Basic Interactions ###################

update:
	bundle update
	git add Gemfile Gemfile.lock
	git commit -m "UPDATE: Gems"
	git push -u heroku master

it:
	git add Makefile $(MAIN) $(VIEWS)
	git commit -m TRY:'$(m)'
	git push -u heroku master

go:
	heroku open

checkpoint:
	git add Makefile $(MAIN) $(VIEWS) Gemfile Gemfile.lock
	git commit -m WORKS:'$(m)'
	git push -u github master
	git push -u heroku master
	curl -G -v  $(SERVER)log_at_asana --data-urlencode "m=$(m)"



##################### App-Specific Import / Exports #####################

import_noora:
	~/Downloads/flip.universal -u ~/Documents/NooraTracking.csv
#	tail -n +2 ~/Documents/NooraTracking.csv > ~/Documents/NooraTrackingReady.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d latest -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/NooraTrackingReady.csv --headerline

import_test:
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d latest -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/TestCCs.csv --headerline

import_hinai:
	~/Downloads/flip.universal -u ~/Documents/Inpatients_0724.csv
	tail -n +9 ~/Documents/Inpatients_0724.csv > ~/Documents/InpatientSampleReady.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d latest -c inpatients -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/InpatientSampleReady.csv --headerline

import_links:
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d latest -c links -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/Links.csv --headerline


###################### App specific Route Triggers ############################

reminder_calls:
	curl http://serene-forest-4377.herokuapp.com/make_reminder_calls

content_updates: $(AUDIO) $(IMAGES) $(VIDEO)
	git add --all $(AUDIO) $(IMAGES) $(VIDEO)
	date >> content_updates
	git commit -m $(CONTENT_MSG)
	git push -u heroku master 
	echo $(CONTENT_MSG) >> ./ACTIVE_COMMIT

meta: $(METADATA)
	git add $(METADATA)
	git commit -m "TRY: Metadata update"
	git push -u heroku master

metarefresh:
	curl http://carecompanion.noorahealth.org/restockmongo


# make ready
# make whole
# make it so

