athlete_events_classified.csv: athlete_events_classified.sqlite3
	sqlite3 athlete_events_classified.sqlite3 -csv -header "SELECT * FROM classification;" > athlete_events_classified.csv
athlete_events_classified.sqlite3: athlete_events.sqlite3
	cp -f athlete_events.sqlite3 athlete_events_classified.sqlite3~
	sqlite3 athlete_events_classified.sqlite3~ -csv -header "$$(cat query1.sql)"
	mv athlete_events_classified.sqlite3~ athlete_events_classified.sqlite3
athlete_events.sqlite3: tosqlite.py athlete_events.csv
	python tosqlite.py athlete_events.sqlite3 athlete_events.csv
athlete_events.csv: Olympics_data.zip
	unzip -p Olympics_data.zip athlete_events.csv > athlete_events.csv
Olympics_data.zip:
	wget https://techtfq.com/s/Olympics_data.zip
clean:
	rm -f Olympics_data.zip
	rm -f athlete_events.csv
	rm -f athlete_events.sqlite3
	rm -f athlete_events_classified.csv
	rm -f athlete_events_classified.sqlite3
	rm -f db.sqlite3
