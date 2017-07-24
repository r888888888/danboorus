set :output, "/var/log/whenever.log"

every 1.day do
  runner "DailyMaintenance.new.run"
end

every 1.week, :at => "1:30 am" do
  runner "WeeklyMaintenance.new.run"
end

every 1.month, :at => "2:00 am" do
  runner "MonthlyMaintenance.new.run"
end
