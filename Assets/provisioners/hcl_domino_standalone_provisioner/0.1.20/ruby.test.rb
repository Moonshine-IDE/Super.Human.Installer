

require 'pty'
responses = "\e[?2004l\r192.168.2.123\r\n"

if responses.to_s.match(/((?:[0-9]{1,3}\.){3}[0-9]{1,3})/)
	p responses.to_s.match(/((?:[0-9]{1,3}\.){3}[0-9]{1,3})/).captures
end
