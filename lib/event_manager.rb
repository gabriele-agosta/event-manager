require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

Date::DAYNAMES.rotate(1)


def clean_zipcode(zipcode)
  # Zipcode is first converted to string, so that we don't have to deal with nil values
  # rjust does its job only when the length of zipcode is less than 5
  # slice does its job only when the length of zipcode is greater than 5
  zipcode.to_s.rjust(5, '0')[0..4]
end


def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin 
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end


def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end


def clean_phone(phone)
  phone = phone.delete("^0-9")
  if phone.length < 10 || phone.length > 11 || (phone.length == 11 && phone[0] != 1)
    return '0000000000'
  elsif phone.length == 10
    return phone
  else
    return phone[1..11]
  end
end


def save_phone_numbers(phones)
  Dir.mkdir('additional_output') unless Dir.exist?('additional_output')
  filename = 'additional_output/phone_numbers.txt'

  File.open(filename, 'w') do |file|
    phones.each { |phone| file.puts phone }
  end
end


def clean_hour(regdate)
  # Da errore con il parse. Probabilmente devo prima convertirlo a data, e poi effettivamente posso usare il tempo.
  datetime = DateTime.strptime(regdate, '%m/%d/%y %H:%M')
  hour = datetime.hour
  #hour = Time.parse(regdate).hour
  return hour
end


def clean_day(regdate)
  date = Date.strptime(regdate, '%m/%d/%y %H:%M')
  day = date.strftime('%A')
  return day
end


def max_value_key(hash)
  max_value = 0
  peak_key = String.new

  hash.each do |key, value|
    if value > max_value
      max_value = value
      peak_key = key
    end
  end
  return peak_key
end


def get_peak_time_range(hours)
  time_ranges = Hash.new
  hours.each do |hour|
    hour_range = "#{hour}-#{hour+1}"
    time_ranges[hour_range] = 1 + (time_ranges[hour_range] || 0)
  end
  return max_value_key(time_ranges)
end


def get_peak_day(days)
  days_frequency = Hash.new

  days.each do |day|
    days_frequency[day] = 1 + (days_frequency[day] || 0)
  end
  return max_value_key(days_frequency)
end



def save_peaks(peak_hour, peak_day)
  Dir.mkdir('additional_output') unless Dir.exist?('additional_output')
  filename = 'additional_output/peaks.txt'

  File.open(filename, 'w') do |file|
    file.puts "Peak registration hour range: #{peak_hour}\nPeak registration day: #{peak_day}"
  end
end


puts 'Event Manager Initialized!'
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
hours = Array.new
days = Array.new
phones = Array.new

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)

  phone = clean_phone(row[:homephone])
  phones.push(phone)

  hour = clean_hour(row[:regdate])
  hours.push(hour)
  
  day = clean_day(row[:regdate])
  days.push(day)
end

peak_hour = get_peak_time_range(hours)
peak_day = get_peak_day(days)
save_peaks(peak_hour, peak_day)
save_phone_numbers(phones)
