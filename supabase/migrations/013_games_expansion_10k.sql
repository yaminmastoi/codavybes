-- VYBE V12: eight Room games + 10,000+ server-side question/prompt bank.
-- Run AFTER 012_certified_verification_waitlist.sql.
begin;
-- Expand the authoritative game type constraints.
alter table public.game_sessions drop constraint if exists game_sessions_game_type_check;
alter table public.game_sessions add constraint game_sessions_game_type_check check (game_type in ('puzzle','trivia','most_likely','would_you_rather','emoji_decode','riddle','word_scramble','spot_lie'));
alter table private.game_question_bank drop constraint if exists game_question_bank_game_type_check;
alter table private.game_question_bank add constraint game_question_bank_game_type_check check (game_type in ('puzzle','trivia','most_likely','would_you_rather','emoji_decode','riddle','word_scramble','spot_lie'));
create index if not exists game_question_bank_type_active_idx on private.game_question_bank(game_type,active,id);

-- Would You Rather: 3,570 safe social matchups from 85 curated choices.
with choices as (select * from unnest(array['travel the world for free','never need sleep','read minds for ten seconds a day','pause time for one minute','always have perfect Wi-Fi','be able to teleport','speak every language','remember everything you read','have unlimited concert tickets','get free food anywhere','live by the ocean','live in the mountains','own a tiny private island','have a personal chef','have a personal driver','always know the right answer','never wait in a line','see one day into the future','replay one day from your past','have perfect luck once a week','be invisible for one hour a day','fly for thirty minutes a day','breathe underwater','talk to animals','control the weather around you','master any instrument instantly','master any sport instantly','never lose your phone','never run out of battery','have your dream room','have your dream gaming setup','get front-row seats forever','have unlimited books','have unlimited movies and shows','eat your favorite meal every day','try a new food every day','wake up energized every morning','never feel jet lag','always find parking instantly','get one extra hour every day','freeze your age for ten years','change your hairstyle instantly','change your outfit instantly','live without social media for a year','live without streaming for a year','only text for a month','only voice-note for a month','be famous online','be respected anonymously','win every board game','win every trivia night','always know when someone is joking','always know when someone is bluffing','have a photographic memory','have perfect handwriting','be amazing at cooking','be amazing at dancing','be amazing at public speaking','be amazing at coding','have a home cinema','have a home arcade','own every sneaker you want','own every book you want','meet your favorite artist','meet your favorite athlete','visit space once','visit the deep ocean once','live in your favorite fictional world for a week','bring one fictional character into real life','redo one awkward moment','skip one boring day every month','always get the window seat','always get the best table','never have ads','never forget a password','have instant room service anywhere','have a robot assistant','have a perfect sense of direction','always know what to say','always make people laugh','have a soundtrack follow your life','have a rewind button for conversations','have a mute button for awkward moments','have your own secret hangout','have unlimited photo storage']::text[]) with ordinality as t(label,n))
insert into private.game_question_bank(game_type,prompt,options,correct_answer)
select 'would_you_rather','Would you rather '||a.label||' or '||b.label||'?',jsonb_build_array(a.label,b.label),null
from choices a join choices b on a.n<b.n on conflict do nothing;

-- Most Likely To: 2,000 clean group prompts.
with actions as (select * from unnest(array['accidentally become famous','start a business','forget why they entered a room','win a random competition','miss a flight','book a spontaneous trip','go viral for something silly','become a streamer','become a CEO','become a teacher','move to another country','learn a new language','adopt a pet','own too many plants','send a message to the wrong chat','laugh at the worst possible moment','sleep through an alarm','stay awake until sunrise','turn a hobby into a career','write a book','make a documentary','start a podcast','delete social media for a month','build a secret side project','win a trivia night','solve a mystery first','get lost with GPS on','make friends in five minutes','remember everyone''s birthday','forget their own password','show up early','show up dramatically late','bring snacks for everyone','order the same meal every time','try the weirdest item on the menu','become the group photographer','take 200 photos on one trip','start dancing first','sing the loudest','turn a tiny story into a ten-minute story','make everyone laugh without trying','stay calm during chaos','panic over a tiny problem','plan the whole trip','forget the trip plan','make a spreadsheet for fun','have 100 unread notifications','reply instantly','reply three days later','lose their keys','find someone else''s lost keys','know a random fact about everything','guess the plot twist','fall asleep during a movie','rewatch the same show','buy something because of the packaging','wear the same favorite outfit','change their style completely','learn an instrument','start working out consistently','run a marathon','climb a mountain','try skydiving','go camping with no plan','survive a zombie movie','be the first to investigate a weird noise','hide during a weird noise','become a meme','invent a catchphrase','name a group chat something ridiculous','create a new inside joke','remember an old inside joke','organize a surprise','spoil a surprise by accident','win a dance battle','win a gaming tournament','rage quit a game','carry the whole team','choose the best playlist','take over the aux cable']::text[]) as t(action)),
suffixes as (select * from unnest(array['this year','before everyone else','by complete accident','on a random weekend','and act like it was planned','without warning anyone','during a group trip','at 2 AM','when nobody expects it','for absolutely no reason','after saying they never would','and somehow make it work','while everyone else is confused','during the next holiday','in the middle of a serious moment','on their first try','after watching one tutorial','because of a dare','after losing a bet','while trying to help','and turn it into a whole story','then pretend it was normal','before the end of the month','in front of the whole group','and get away with it']::text[]) as t(suffix))
insert into private.game_question_bank(game_type,prompt,options,correct_answer)
select 'most_likely','Who is most likely to '||action||' '||suffix||'?','[]'::jsonb,null from actions cross join suffixes on conflict do nothing;

-- Puzzle Battle: 2,500 deterministic arithmetic/logic speed puzzles.
insert into private.game_question_bank(game_type,prompt,options,correct_answer)
select 'puzzle',
  'Speed puzzle: ('||a||' × '||b||') + '||c||' = ?',
  case (n % 4)
    when 0 then jsonb_build_array(ans::text,(ans+1)::text,(ans-1)::text,(ans+a)::text)
    when 1 then jsonb_build_array((ans+1)::text,ans::text,(ans+a)::text,(ans-1)::text)
    when 2 then jsonb_build_array((ans-1)::text,(ans+a)::text,ans::text,(ans+1)::text)
    else jsonb_build_array((ans+a)::text,(ans-1)::text,(ans+1)::text,ans::text) end,
  ans::text
from (select n, 2+(n%97) a, 2+((n*7)%89) b, ((n*13)%41) c, (2+(n%97))*(2+((n*7)%89))+((n*13)%41) ans from generate_series(1,2500) n) q
on conflict do nothing;

-- Spot the Lie: 2,000 mathematically verifiable statement sets.
insert into private.game_question_bank(game_type,prompt,options,correct_answer)
select 'spot_lie','Spot the lie #'||n||' — which statement is false?',
  case (n % 4)
    when 0 then jsonb_build_array(t1,t2,f1,t3)
    when 1 then jsonb_build_array(f1,t1,t3,t2)
    when 2 then jsonb_build_array(t3,f1,t2,t1)
    else jsonb_build_array(t2,t3,t1,f1) end, f1
from (
  select n,a,b,(a*b)::text,
   a||' × '||b||' = '||(a*b) t1,
   (a*b)||' ÷ '||b||' = '||a t2,
   a||' - '||b||' = '||(a-b) t3,
   a||' + '||b||' = '||(a+b+1) f1
  from (select n,10+(n%211) a,2+((n*5)%17) b from generate_series(1,2000) n) s
) q on conflict do nothing;

-- Riddle Rush: 500 number riddles.
insert into private.game_question_bank(game_type,prompt,options,correct_answer)
select 'riddle','I am a number. Triple me, then add '||bonus||', and you get '||(n*3+bonus)||'. What number am I?',
  case (n%4) when 0 then jsonb_build_array(n::text,(n+1)::text,(n+2)::text,greatest(1,n-1)::text) when 1 then jsonb_build_array((n+2)::text,n::text,greatest(1,n-1)::text,(n+1)::text) when 2 then jsonb_build_array((n+1)::text,greatest(1,n-1)::text,n::text,(n+2)::text) else jsonb_build_array(greatest(1,n-1)::text,(n+2)::text,(n+1)::text,n::text) end,n::text
from (select n,1+((n*7)%23) bonus from generate_series(2,501) n) q on conflict do nothing;

-- Word Scramble: 600 rounds from 200 friendly words × 3 scramble patterns.
with words as (select * from unnest(array['adventure','airport','amazing','arcade','artist','balance','battery','beach','camera','captain','career','castle','coffee','comedy','concert','cookie','creative','crystal','culture','dancer','design','digital','dragon','dreamer','energy','festival','fitness','forest','friend','future','galaxy','gaming','garden','guitar','hacker','holiday','horizon','internet','island','jacket','journey','laptop','legend','library','magnet','market','master','memory','midnight','moment','mountain','museum','mystery','nature','network','ocean','orange','painter','passport','planet','playlist','pocket','puzzle','rocket','school','secret','shadow','signal','silver','speaker','stadium','summer','sunrise','sunset','travel','treasure','trophy','universe','vacation','vintage','vision','wallet','weekend','window','winner','winter','wonder','writer','yellow','zodiac','breeze','button','circle','compass','diamond','electric','freedom','glacier','harbor','jungle','lantern','mirror','notebook','phoenix','rainbow','rhythm','safari','satellite','sketch','studio','thunder','velvet','voyage','whisper','anchor','bridge','cinema','clover','cosmic','engine','feather','flame','gravity','helmet','isotope','marble','meteor','neon','orbit','paradox','pixel','quartz','riddle','spectrum','summit','tempo','vector','wander','zenith','bubble','cactus','canvas','cherry','cobalt','comet','coral','ember','fable','fluent','frost','harmony','jigsaw','kettle','lagoon','matrix','meadow','mosaic','nebula','pebble','prism','radar','raven','retro','sprint','storm','tunnel','violet','waveform','wildcard','aurora','blossom','cascade','cipher','cosmos','echo','fusion','groove','huddle','ignite','jovial','kinetic','lunar','mingle','nova','pulse','quest','rover','spark','uplink','vortex','wanderer','xenon','yonder','zephyr','banter','chatter','clutch','crush','doodle','glitch']::text[]) with ordinality as t(word,n)),
variants as (select w.*,v.mode from words w cross join generate_series(1,3) v(mode)),
pool as (select *, count(*) over() total from words)
insert into private.game_question_bank(game_type,prompt,options,correct_answer)
select 'word_scramble',
 'Unscramble this word: '||upper(case v.mode when 1 then reverse(v.word) when 2 then substr(v.word,3)||substr(v.word,1,2) else substr(v.word,2)||substr(v.word,1,1) end),
 case ((v.n+v.mode)%4)
  when 0 then jsonb_build_array(v.word,d1.word,d2.word,d3.word)
  when 1 then jsonb_build_array(d1.word,v.word,d3.word,d2.word)
  when 2 then jsonb_build_array(d2.word,d3.word,v.word,d1.word)
  else jsonb_build_array(d3.word,d2.word,d1.word,v.word) end,
 v.word
from variants v
join words d1 on d1.n=((v.n+37-1)%200)+1
join words d2 on d2.n=((v.n+83-1)%200)+1
join words d3 on d3.n=((v.n+131-1)%200)+1
on conflict do nothing;

-- Rapid Trivia: 612 curated geography questions generated from the bundled country dataset.
insert into private.game_question_bank(game_type,prompt,options,correct_answer) values
('trivia','Which country has Kabul as its capital?','["Afghanistan", "Belarus", "Colombia", "Greece"]'::jsonb,'Afghanistan'),
('trivia','What is the capital of Afghanistan?','["Nassau", "Bangui", "Papeetē", "Kabul"]'::jsonb,'Kabul'),
('trivia','Which of these countries uses currency code AFN?','["Czech Republic", "Hong Kong", "Afghanistan", "Bolivia"]'::jsonb,'Afghanistan'),
('trivia','Which country has Tirana as its capital?','["Belgium", "Comoros", "Greenland", "Albania"]'::jsonb,'Albania'),
('trivia','What is the capital of Albania?','["N''Djamena", "Port-aux-Français", "Tirana", "Manama"]'::jsonb,'Tirana'),
('trivia','Which of these countries uses currency code ALL?','["Hungary", "Albania", "Bosnia and Herzegovina", "Denmark"]'::jsonb,'Albania'),
('trivia','Which country has Algiers as its capital?','["Republic of the Congo", "Grenada", "Algeria", "Belize"]'::jsonb,'Algeria'),
('trivia','What is the capital of Algeria?','["Libreville", "Algiers", "Dhaka", "Santiago"]'::jsonb,'Algiers'),
('trivia','Which of these countries uses currency code DZD?','["Algeria", "Botswana", "Djibouti", "Iceland"]'::jsonb,'Algeria'),
('trivia','Which country has Pago Pago as its capital?','["Guadeloupe", "American Samoa", "Benin", "Democratic Republic of the Congo"]'::jsonb,'American Samoa'),
('trivia','What is the capital of American Samoa?','["Pago Pago", "Bridgetown", "Beijing", "Banjul"]'::jsonb,'Pago Pago'),
('trivia','Which of these countries uses currency code USD?','["Brazil", "Dominica", "India", "American Samoa"]'::jsonb,'American Samoa'),
('trivia','Which country has Luanda as its capital?','["Angola", "Bermuda", "Cook Islands", "Guam"]'::jsonb,'Angola'),
('trivia','What is the capital of Angola?','["Minsk", "Flying Fish Cove", "Tbilisi", "Luanda"]'::jsonb,'Luanda'),
('trivia','Which of these countries uses currency code AOA?','["Dominican Republic", "Indonesia", "Angola", "British Indian Ocean Territory"]'::jsonb,'Angola'),
('trivia','Which country has The Valley as its capital?','["Bhutan", "Costa Rica", "Guatemala", "Anguilla"]'::jsonb,'Anguilla'),
('trivia','What is the capital of Anguilla?','["West Island", "Berlin", "The Valley", "Brussels"]'::jsonb,'The Valley'),
('trivia','Which of these countries uses currency code XCD?','["Iran", "Anguilla", "Brunei", "Ecuador"]'::jsonb,'Anguilla'),
('trivia','Which country has Saint John''s as its capital?','["Ivory Coast", "Guernsey", "Antigua and Barbuda", "Bolivia"]'::jsonb,'Antigua and Barbuda'),
('trivia','What is the capital of Antigua and Barbuda?','["Accra", "Saint John''s", "Belmopan", "Bogotá"]'::jsonb,'Saint John''s'),
('trivia','Which country has Buenos Aires as its capital?','["Guinea", "Argentina", "Bosnia and Herzegovina", "Croatia"]'::jsonb,'Argentina'),
('trivia','What is the capital of Argentina?','["Buenos Aires", "Porto-Novo", "Moroni", "Gibraltar"]'::jsonb,'Buenos Aires'),
('trivia','Which of these countries uses currency code ARS?','["Burkina Faso", "El Salvador", "Ireland", "Argentina"]'::jsonb,'Argentina'),
('trivia','Which country has Yerevan as its capital?','["Armenia", "Botswana", "Cuba", "Guinea-Bissau"]'::jsonb,'Armenia'),
('trivia','What is the capital of Armenia?','["Hamilton", "Brazzaville", "Athens", "Yerevan"]'::jsonb,'Yerevan'),
('trivia','Which of these countries uses currency code AMD?','["Equatorial Guinea", "Israel", "Armenia", "Burundi"]'::jsonb,'Armenia'),
('trivia','Which country has Oranjestad as its capital?','["Brazil", "Cyprus", "Guyana", "Aruba"]'::jsonb,'Aruba'),
('trivia','What is the capital of Aruba?','["Kinshasa", "Nuuk", "Oranjestad", "Thimphu"]'::jsonb,'Oranjestad'),
('trivia','Which of these countries uses currency code AWG?','["Italy", "Aruba", "Cambodia", "Eritrea"]'::jsonb,'Aruba'),
('trivia','Which country has Canberra as its capital?','["Czech Republic", "Haiti", "Australia", "British Indian Ocean Territory"]'::jsonb,'Australia'),
('trivia','What is the capital of Australia?','["St. George''s", "Canberra", "Sucre", "Avarua"]'::jsonb,'Canberra'),
('trivia','Which of these countries uses currency code AUD?','["Australia", "Cameroon", "Estonia", "Jamaica"]'::jsonb,'Australia'),
('trivia','Which country has Vienna as its capital?','["Honduras", "Austria", "Brunei", "Denmark"]'::jsonb,'Austria'),
('trivia','What is the capital of Austria?','["Vienna", "Sarajevo", "San José", "Basse-Terre"]'::jsonb,'Vienna'),
('trivia','Which of these countries uses currency code EUR?','["Canada", "Ethiopia", "Japan", "Austria"]'::jsonb,'Austria'),
('trivia','Which country has Baku as its capital?','["Azerbaijan", "Bulgaria", "Djibouti", "Hong Kong"]'::jsonb,'Azerbaijan'),
('trivia','What is the capital of Azerbaijan?','["Gaborone", "Yamoussoukro", "Hagåtña", "Baku"]'::jsonb,'Baku'),
('trivia','Which of these countries uses currency code AZN?','["Falkland Islands", "Jersey", "Azerbaijan", "Cape Verde"]'::jsonb,'Azerbaijan'),
('trivia','Which country has Nassau as its capital?','["Burkina Faso", "Dominica", "Hungary", "The Bahamas"]'::jsonb,'The Bahamas'),
('trivia','What is the capital of The Bahamas?','["Zagreb", "Guatemala City", "Nassau", "Brasília"]'::jsonb,'Nassau'),
('trivia','Which of these countries uses currency code BSD?','["Jordan", "The Bahamas", "Cayman Islands", "Faroe Islands"]'::jsonb,'The Bahamas'),
('trivia','Which country has Manama as its capital?','["Dominican Republic", "Iceland", "Bahrain", "Burundi"]'::jsonb,'Bahrain'),
('trivia','What is the capital of Bahrain?','["St. Peter Port", "Manama", "Diego Garcia", "Havana"]'::jsonb,'Manama'),
('trivia','Which of these countries uses currency code BHD?','["Bahrain", "Central African Republic", "Fiji", "Kazakhstan"]'::jsonb,'Bahrain'),
('trivia','Which country has Dhaka as its capital?','["India", "Bangladesh", "Cambodia", "Ecuador"]'::jsonb,'Bangladesh'),
('trivia','What is the capital of Bangladesh?','["Dhaka", "Bandar Seri Begawan", "Nicosia", "Conakry"]'::jsonb,'Dhaka'),
('trivia','Which of these countries uses currency code BDT?','["Chad", "Finland", "Kenya", "Bangladesh"]'::jsonb,'Bangladesh'),
('trivia','Which country has Bridgetown as its capital?','["Barbados", "Cameroon", "Egypt", "Indonesia"]'::jsonb,'Barbados'),
('trivia','What is the capital of Barbados?','["Sofia", "Prague", "Bissau", "Bridgetown"]'::jsonb,'Bridgetown'),
('trivia','Which of these countries uses currency code BBD?','["France", "Kiribati", "Barbados", "Chile"]'::jsonb,'Barbados'),
('trivia','Which country has Minsk as its capital?','["Canada", "El Salvador", "Iran", "Belarus"]'::jsonb,'Belarus'),
('trivia','What is the capital of Belarus?','["Copenhagen", "Georgetown", "Minsk", "Ouagadougou"]'::jsonb,'Minsk'),
('trivia','Which of these countries uses currency code BYR?','["North Korea", "Belarus", "China", "French Guiana"]'::jsonb,'Belarus'),
('trivia','Which country has Brussels as its capital?','["Equatorial Guinea", "Iraq", "Belgium", "Cape Verde"]'::jsonb,'Belgium'),
('trivia','What is the capital of Belgium?','["Port-au-Prince", "Brussels", "Bujumbura", "Djibouti"]'::jsonb,'Brussels'),
('trivia','Which country has Belmopan as its capital?','["Ireland", "Belize", "Cayman Islands", "Eritrea"]'::jsonb,'Belize'),
('trivia','What is the capital of Belize?','["Belmopan", "Phnom Penh", "Roseau", "Tegucigalpa"]'::jsonb,'Belmopan'),
('trivia','Which of these countries uses currency code BZD?','["Cocos (Keeling) Islands", "French Southern and Antarctic Lands", "Kuwait", "Belize"]'::jsonb,'Belize'),
('trivia','Which country has Porto-Novo as its capital?','["Benin", "Central African Republic", "Estonia", "Israel"]'::jsonb,'Benin'),
('trivia','What is the capital of Benin?','["Yaoundé", "Santo Domingo", "City of Victoria", "Porto-Novo"]'::jsonb,'Porto-Novo'),
('trivia','Which of these countries uses currency code XOF?','["Gabon", "Kyrgyzstan", "Benin", "Colombia"]'::jsonb,'Benin'),
('trivia','Which country has Hamilton as its capital?','["Chad", "Ethiopia", "Italy", "Bermuda"]'::jsonb,'Bermuda'),
('trivia','What is the capital of Bermuda?','["Quito", "Budapest", "Hamilton", "Ottawa"]'::jsonb,'Hamilton'),
('trivia','Which of these countries uses currency code BMD?','["Laos", "Bermuda", "Comoros", "The Gambia"]'::jsonb,'Bermuda'),
('trivia','Which country has Thimphu as its capital?','["Falkland Islands", "Jamaica", "Bhutan", "Chile"]'::jsonb,'Bhutan'),
('trivia','What is the capital of Bhutan?','["Reykjavik", "Thimphu", "Praia", "Cairo"]'::jsonb,'Thimphu'),
('trivia','Which of these countries uses currency code BTN?','["Bhutan", "Republic of the Congo", "Georgia", "Latvia"]'::jsonb,'Bhutan'),
('trivia','Which country has Sucre as its capital?','["Japan", "Bolivia", "China", "Faroe Islands"]'::jsonb,'Bolivia'),
('trivia','What is the capital of Bolivia?','["Sucre", "George Town", "San Salvador", "New Delhi"]'::jsonb,'Sucre'),
('trivia','Which of these countries uses currency code BOB?','["Democratic Republic of the Congo", "Germany", "Lebanon", "Bolivia"]'::jsonb,'Bolivia'),
('trivia','Which country has Sarajevo as its capital?','["Bosnia and Herzegovina", "Christmas Island", "Fiji", "Jersey"]'::jsonb,'Bosnia and Herzegovina'),
('trivia','What is the capital of Bosnia and Herzegovina?','["Bangui", "Malabo", "Jakarta", "Sarajevo"]'::jsonb,'Sarajevo'),
('trivia','Which of these countries uses currency code BAM?','["Ghana", "Lesotho", "Bosnia and Herzegovina", "Cook Islands"]'::jsonb,'Bosnia and Herzegovina'),
('trivia','Which country has Gaborone as its capital?','["Cocos (Keeling) Islands", "Finland", "Jordan", "Botswana"]'::jsonb,'Botswana'),
('trivia','What is the capital of Botswana?','["Asmara", "Tehran", "Gaborone", "N''Djamena"]'::jsonb,'Gaborone'),
('trivia','Which of these countries uses currency code BWP?','["Liberia", "Botswana", "Costa Rica", "Gibraltar"]'::jsonb,'Botswana'),
('trivia','Which country has Brasília as its capital?','["France", "Kazakhstan", "Brazil", "Colombia"]'::jsonb,'Brazil'),
('trivia','What is the capital of Brazil?','["Baghdad", "Brasília", "Santiago", "Tallinn"]'::jsonb,'Brasília'),
('trivia','Which of these countries uses currency code BRL?','["Brazil", "Ivory Coast", "Greece", "Libya"]'::jsonb,'Brazil'),
('trivia','Which country has Diego Garcia as its capital?','["Kenya", "British Indian Ocean Territory", "Comoros", "French Guiana"]'::jsonb,'British Indian Ocean Territory'),
('trivia','What is the capital of British Indian Ocean Territory?','["Diego Garcia", "Beijing", "Addis Ababa", "Dublin"]'::jsonb,'Diego Garcia'),
('trivia','Which country has Bandar Seri Begawan as its capital?','["Brunei", "Republic of the Congo", "French Polynesia", "Kiribati"]'::jsonb,'Brunei'),
('trivia','What is the capital of Brunei?','["Flying Fish Cove", "Stanley", "Jerusalem", "Bandar Seri Begawan"]'::jsonb,'Bandar Seri Begawan'),
('trivia','Which of these countries uses currency code BND?','["Grenada", "Lithuania", "Brunei", "Cuba"]'::jsonb,'Brunei'),
('trivia','Which country has Sofia as its capital?','["Democratic Republic of the Congo", "French Southern and Antarctic Lands", "North Korea", "Bulgaria"]'::jsonb,'Bulgaria'),
('trivia','What is the capital of Bulgaria?','["Tórshavn", "Rome", "Sofia", "West Island"]'::jsonb,'Sofia'),
('trivia','Which of these countries uses currency code BGN?','["Luxembourg", "Bulgaria", "Cyprus", "Guadeloupe"]'::jsonb,'Bulgaria'),
('trivia','Which country has Ouagadougou as its capital?','["Gabon", "South Korea", "Burkina Faso", "Cook Islands"]'::jsonb,'Burkina Faso'),
('trivia','What is the capital of Burkina Faso?','["Kingston", "Ouagadougou", "Bogotá", "Suva"]'::jsonb,'Ouagadougou'),
('trivia','Which country has Bujumbura as its capital?','["Kuwait", "Burundi", "Costa Rica", "The Gambia"]'::jsonb,'Burundi'),
('trivia','What is the capital of Burundi?','["Bujumbura", "Moroni", "Helsinki", "Tokyo"]'::jsonb,'Bujumbura'),
('trivia','Which of these countries uses currency code BIF?','["Denmark", "Guatemala", "Madagascar", "Burundi"]'::jsonb,'Burundi'),
('trivia','Which country has Phnom Penh as its capital?','["Cambodia", "Ivory Coast", "Georgia", "Kyrgyzstan"]'::jsonb,'Cambodia'),
('trivia','What is the capital of Cambodia?','["Brazzaville", "Paris", "Saint Helier", "Phnom Penh"]'::jsonb,'Phnom Penh'),
('trivia','Which of these countries uses currency code KHR?','["Guernsey", "Malawi", "Cambodia", "Djibouti"]'::jsonb,'Cambodia'),
('trivia','Which country has Yaoundé as its capital?','["Croatia", "Germany", "Laos", "Cameroon"]'::jsonb,'Cameroon'),
('trivia','What is the capital of Cameroon?','["Cayenne", "Amman", "Yaoundé", "Kinshasa"]'::jsonb,'Yaoundé'),
('trivia','Which of these countries uses currency code XAF?','["Malaysia", "Cameroon", "Dominica", "Guinea"]'::jsonb,'Cameroon'),
('trivia','Which country has Ottawa as its capital?','["Ghana", "Latvia", "Canada", "Cuba"]'::jsonb,'Canada'),
('trivia','What is the capital of Canada?','["Astana", "Ottawa", "Avarua", "Papeetē"]'::jsonb,'Ottawa'),
('trivia','Which of these countries uses currency code CAD?','["Canada", "Dominican Republic", "Guinea-Bissau", "Maldives"]'::jsonb,'Canada'),
('trivia','Which country has Praia as its capital?','["Lebanon", "Cape Verde", "Cyprus", "Gibraltar"]'::jsonb,'Cape Verde'),
('trivia','What is the capital of Cape Verde?','["Praia", "San José", "Port-aux-Français", "Nairobi"]'::jsonb,'Praia'),
('trivia','Which of these countries uses currency code CVE?','["Ecuador", "Guyana", "Mali", "Cape Verde"]'::jsonb,'Cape Verde'),
('trivia','Which country has George Town as its capital?','["Cayman Islands", "Czech Republic", "Greece", "Lesotho"]'::jsonb,'Cayman Islands'),
('trivia','What is the capital of Cayman Islands?','["Yamoussoukro", "Libreville", "South Tarawa", "George Town"]'::jsonb,'George Town'),
('trivia','Which of these countries uses currency code KYD?','["Haiti", "Malta", "Cayman Islands", "Egypt"]'::jsonb,'Cayman Islands'),
('trivia','Which country has Bangui as its capital?','["Denmark", "Greenland", "Liberia", "Central African Republic"]'::jsonb,'Central African Republic'),
('trivia','What is the capital of Central African Republic?','["Banjul", "Pyongyang", "Bangui", "Zagreb"]'::jsonb,'Bangui'),
('trivia','Which country has N''Djamena as its capital?','["Grenada", "Libya", "Chad", "Djibouti"]'::jsonb,'Chad'),
('trivia','What is the capital of Chad?','["Seoul", "N''Djamena", "Havana", "Tbilisi"]'::jsonb,'N''Djamena'),
('trivia','Which country has Santiago as its capital?','["Liechtenstein", "Chile", "Dominica", "Guadeloupe"]'::jsonb,'Chile'),
('trivia','What is the capital of Chile?','["Santiago", "Nicosia", "Berlin", "Kuwait City"]'::jsonb,'Santiago'),
('trivia','Which of these countries uses currency code CLF?','["Eritrea", "Hungary", "Martinique", "Chile"]'::jsonb,'Chile'),
('trivia','Which country has Beijing as its capital?','["China", "Dominican Republic", "Guam", "Lithuania"]'::jsonb,'China'),
('trivia','What is the capital of China?','["Prague", "Accra", "Bishkek", "Beijing"]'::jsonb,'Beijing'),
('trivia','Which of these countries uses currency code CNY?','["Iceland", "Mauritania", "China", "Estonia"]'::jsonb,'China'),
('trivia','Which country has Flying Fish Cove as its capital?','["Ecuador", "Guatemala", "Luxembourg", "Christmas Island"]'::jsonb,'Christmas Island'),
('trivia','What is the capital of Christmas Island?','["Gibraltar", "Vientiane", "Flying Fish Cove", "Copenhagen"]'::jsonb,'Flying Fish Cove'),
('trivia','Which country has West Island as its capital?','["Guernsey", "Republic of Macedonia", "Cocos (Keeling) Islands", "Egypt"]'::jsonb,'Cocos (Keeling) Islands'),
('trivia','What is the capital of Cocos (Keeling) Islands?','["Riga", "West Island", "Djibouti", "Athens"]'::jsonb,'West Island'),
('trivia','Which country has Bogotá as its capital?','["Madagascar", "Colombia", "El Salvador", "Guinea"]'::jsonb,'Colombia'),
('trivia','What is the capital of Colombia?','["Bogotá", "Roseau", "Nuuk", "Beirut"]'::jsonb,'Bogotá'),
('trivia','Which of these countries uses currency code COP?','["Faroe Islands", "Iran", "Mexico", "Colombia"]'::jsonb,'Colombia'),
('trivia','Which country has Moroni as its capital?','["Comoros", "Equatorial Guinea", "Guinea-Bissau", "Malawi"]'::jsonb,'Comoros'),
('trivia','What is the capital of Comoros?','["Santo Domingo", "St. George''s", "Maseru", "Moroni"]'::jsonb,'Moroni'),
('trivia','Which of these countries uses currency code KMF?','["Iraq", "Federated States of Micronesia", "Comoros", "Fiji"]'::jsonb,'Comoros'),
('trivia','Which country has Brazzaville as its capital?','["Eritrea", "Guyana", "Malaysia", "Republic of the Congo"]'::jsonb,'Republic of the Congo'),
('trivia','What is the capital of Republic of the Congo?','["Basse-Terre", "Monrovia", "Brazzaville", "Quito"]'::jsonb,'Brazzaville'),
('trivia','Which country has Kinshasa as its capital?','["Haiti", "Maldives", "Democratic Republic of the Congo", "Estonia"]'::jsonb,'Democratic Republic of the Congo'),
('trivia','What is the capital of Democratic Republic of the Congo?','["Tripoli", "Kinshasa", "Cairo", "Hagåtña"]'::jsonb,'Kinshasa'),
('trivia','Which of these countries uses currency code CDF?','["Democratic Republic of the Congo", "France", "Israel", "Monaco"]'::jsonb,'Democratic Republic of the Congo'),
('trivia','Which country has Avarua as its capital?','["Mali", "Cook Islands", "Ethiopia", "Honduras"]'::jsonb,'Cook Islands'),
('trivia','What is the capital of Cook Islands?','["Avarua", "San Salvador", "Guatemala City", "Vaduz"]'::jsonb,'Avarua'),
('trivia','Which of these countries uses currency code NZD?','["French Guiana", "Italy", "Mongolia", "Cook Islands"]'::jsonb,'Cook Islands'),
('trivia','Which country has San José as its capital?','["Costa Rica", "Falkland Islands", "Hong Kong", "Malta"]'::jsonb,'Costa Rica'),
('trivia','What is the capital of Costa Rica?','["Malabo", "St. Peter Port", "Vilnius", "San José"]'::jsonb,'San José'),
('trivia','Which of these countries uses currency code CRC?','["Jamaica", "Montserrat", "Costa Rica", "French Polynesia"]'::jsonb,'Costa Rica'),
('trivia','Which country has Yamoussoukro as its capital?','["Faroe Islands", "Hungary", "Isle of Man", "Ivory Coast"]'::jsonb,'Ivory Coast'),
('trivia','What is the capital of Ivory Coast?','["Conakry", "Luxembourg", "Yamoussoukro", "Asmara"]'::jsonb,'Yamoussoukro'),
('trivia','Which country has Zagreb as its capital?','["Iceland", "Marshall Islands", "Croatia", "Fiji"]'::jsonb,'Croatia'),
('trivia','What is the capital of Croatia?','["Skopje", "Zagreb", "Tallinn", "Bissau"]'::jsonb,'Zagreb'),
('trivia','Which of these countries uses currency code HRK?','["Croatia", "Gabon", "Jersey", "Mozambique"]'::jsonb,'Croatia'),
('trivia','Which country has Havana as its capital?','["Martinique", "Cuba", "Finland", "India"]'::jsonb,'Cuba'),
('trivia','What is the capital of Cuba?','["Havana", "Addis Ababa", "Georgetown", "Antananarivo"]'::jsonb,'Havana'),
('trivia','Which of these countries uses currency code CUC?','["The Gambia", "Jordan", "Namibia", "Cuba"]'::jsonb,'Cuba'),
('trivia','Which country has Nicosia as its capital?','["Cyprus", "France", "Indonesia", "Mauritania"]'::jsonb,'Cyprus'),
('trivia','What is the capital of Cyprus?','["Stanley", "Port-au-Prince", "Lilongwe", "Nicosia"]'::jsonb,'Nicosia'),
('trivia','Which country has Prague as its capital?','["French Guiana", "Iran", "Mauritius", "Czech Republic"]'::jsonb,'Czech Republic'),
('trivia','What is the capital of Czech Republic?','["Tegucigalpa", "Kuala Lumpur", "Prague", "Tórshavn"]'::jsonb,'Prague'),
('trivia','Which of these countries uses currency code CZK?','["Nepal", "Czech Republic", "Germany", "Kenya"]'::jsonb,'Czech Republic'),
('trivia','Which country has Copenhagen as its capital?','["Iraq", "Mayotte", "Denmark", "French Polynesia"]'::jsonb,'Denmark'),
('trivia','What is the capital of Denmark?','["Malé", "Copenhagen", "Suva", "City of Victoria"]'::jsonb,'Copenhagen'),
('trivia','Which of these countries uses currency code DKK?','["Denmark", "Ghana", "Kiribati", "Netherlands"]'::jsonb,'Denmark'),
('trivia','Which country has Djibouti as its capital?','["Mexico", "Djibouti", "French Southern and Antarctic Lands", "Ireland"]'::jsonb,'Djibouti'),
('trivia','What is the capital of Djibouti?','["Djibouti", "Helsinki", "Budapest", "Bamako"]'::jsonb,'Djibouti'),
('trivia','Which of these countries uses currency code DJF?','["Gibraltar", "North Korea", "New Caledonia", "Djibouti"]'::jsonb,'Djibouti'),
('trivia','Which country has Roseau as its capital?','["Dominica", "Gabon", "Israel", "Federated States of Micronesia"]'::jsonb,'Dominica'),
('trivia','What is the capital of Dominica?','["Paris", "Reykjavik", "Valletta", "Roseau"]'::jsonb,'Roseau'),
('trivia','Which country has Santo Domingo as its capital?','["The Gambia", "Italy", "Moldova", "Dominican Republic"]'::jsonb,'Dominican Republic'),
('trivia','What is the capital of Dominican Republic?','["New Delhi", "Douglas", "Santo Domingo", "Cayenne"]'::jsonb,'Santo Domingo'),
('trivia','Which of these countries uses currency code DOP?','["Nicaragua", "Dominican Republic", "Greenland", "Kuwait"]'::jsonb,'Dominican Republic'),
('trivia','Which country has Quito as its capital?','["Jamaica", "Monaco", "Ecuador", "Georgia"]'::jsonb,'Ecuador'),
('trivia','What is the capital of Ecuador?','["Majuro", "Quito", "Papeetē", "Jakarta"]'::jsonb,'Quito'),
('trivia','Which country has Cairo as its capital?','["Mongolia", "Egypt", "Germany", "Japan"]'::jsonb,'Egypt'),
('trivia','What is the capital of Egypt?','["Cairo", "Port-aux-Français", "Tehran", "Fort-de-France"]'::jsonb,'Cairo'),
('trivia','Which of these countries uses currency code EGP?','["Guadeloupe", "Laos", "Nigeria", "Egypt"]'::jsonb,'Egypt'),
('trivia','Which country has San Salvador as its capital?','["El Salvador", "Ghana", "Jersey", "Montserrat"]'::jsonb,'El Salvador'),
('trivia','What is the capital of El Salvador?','["Libreville", "Baghdad", "Nouakchott", "San Salvador"]'::jsonb,'San Salvador'),
('trivia','Which of these countries uses currency code SVC?','["Latvia", "Niue", "El Salvador", "Guam"]'::jsonb,'El Salvador'),
('trivia','Which country has Malabo as its capital?','["Gibraltar", "Jordan", "Morocco", "Equatorial Guinea"]'::jsonb,'Equatorial Guinea'),
('trivia','What is the capital of Equatorial Guinea?','["Dublin", "Port Louis", "Malabo", "Banjul"]'::jsonb,'Malabo'),
('trivia','Which country has Asmara as its capital?','["Kazakhstan", "Mozambique", "Eritrea", "Greece"]'::jsonb,'Eritrea'),
('trivia','What is the capital of Eritrea?','["Mamoudzou", "Asmara", "Tbilisi", "Jerusalem"]'::jsonb,'Asmara'),
('trivia','Which of these countries uses currency code ERN?','["Eritrea", "Guernsey", "Lesotho", "Northern Mariana Islands"]'::jsonb,'Eritrea'),
('trivia','Which country has Tallinn as its capital?','["Namibia", "Estonia", "Greenland", "Kenya"]'::jsonb,'Estonia'),
('trivia','What is the capital of Estonia?','["Tallinn", "Berlin", "Rome", "Mexico City"]'::jsonb,'Tallinn'),
('trivia','Which country has Addis Ababa as its capital?','["Ethiopia", "Grenada", "Kiribati", "Nauru"]'::jsonb,'Ethiopia'),
('trivia','What is the capital of Ethiopia?','["Accra", "Kingston", "Palikir", "Addis Ababa"]'::jsonb,'Addis Ababa'),
('trivia','Which of these countries uses currency code ETB?','["Libya", "Oman", "Ethiopia", "Guinea-Bissau"]'::jsonb,'Ethiopia'),
('trivia','Which country has Stanley as its capital?','["Guadeloupe", "North Korea", "Nepal", "Falkland Islands"]'::jsonb,'Falkland Islands'),
('trivia','What is the capital of Falkland Islands?','["Tokyo", "Chișinău", "Stanley", "Gibraltar"]'::jsonb,'Stanley'),
('trivia','Which of these countries uses currency code FKP?','["Pakistan", "Falkland Islands", "Guyana", "Liechtenstein"]'::jsonb,'Falkland Islands'),
('trivia','Which country has Tórshavn as its capital?','["South Korea", "Netherlands", "Faroe Islands", "Guam"]'::jsonb,'Faroe Islands'),
('trivia','What is the capital of Faroe Islands?','["Monaco", "Tórshavn", "Athens", "Saint Helier"]'::jsonb,'Tórshavn'),
('trivia','Which country has Suva as its capital?','["New Caledonia", "Fiji", "Guatemala", "Kuwait"]'::jsonb,'Fiji'),
('trivia','What is the capital of Fiji?','["Suva", "Nuuk", "Amman", "Ulan Bator"]'::jsonb,'Suva'),
('trivia','Which of these countries uses currency code FJD?','["Honduras", "Luxembourg", "Panama", "Fiji"]'::jsonb,'Fiji'),
('trivia','Which country has Helsinki as its capital?','["Finland", "Guernsey", "Kyrgyzstan", "New Zealand"]'::jsonb,'Finland'),
('trivia','What is the capital of Finland?','["St. George''s", "Astana", "Plymouth", "Helsinki"]'::jsonb,'Helsinki'),
('trivia','Which country has Paris as its capital?','["Guinea", "Laos", "Nicaragua", "France"]'::jsonb,'France'),
('trivia','What is the capital of France?','["Nairobi", "Rabat", "Paris", "Basse-Terre"]'::jsonb,'Paris'),
('trivia','Which country has Cayenne as its capital?','["Latvia", "Niger", "French Guiana", "Guinea-Bissau"]'::jsonb,'French Guiana'),
('trivia','What is the capital of French Guiana?','["Maputo", "Cayenne", "Hagåtña", "South Tarawa"]'::jsonb,'Cayenne'),
('trivia','Which country has Papeetē as its capital?','["Nigeria", "French Polynesia", "Guyana", "Lebanon"]'::jsonb,'French Polynesia'),
('trivia','What is the capital of French Polynesia?','["Papeetē", "Guatemala City", "Pyongyang", "Windhoek"]'::jsonb,'Papeetē'),
('trivia','Which of these countries uses currency code XPF?','["India", "Malaysia", "Philippines", "French Polynesia"]'::jsonb,'French Polynesia'),
('trivia','Which country has Port-aux-Français as its capital?','["French Southern and Antarctic Lands", "Haiti", "Lesotho", "Niue"]'::jsonb,'French Southern and Antarctic Lands'),
('trivia','What is the capital of French Southern and Antarctic Lands?','["St. Peter Port", "Seoul", "Yaren", "Port-aux-Français"]'::jsonb,'Port-aux-Français'),
('trivia','Which country has Libreville as its capital?','["Honduras", "Liberia", "Norfolk Island", "Gabon"]'::jsonb,'Gabon'),
('trivia','What is the capital of Gabon?','["Kuwait City", "Kathmandu", "Libreville", "Conakry"]'::jsonb,'Libreville'),
('trivia','Which country has Banjul as its capital?','["Libya", "Northern Mariana Islands", "The Gambia", "Hong Kong"]'::jsonb,'The Gambia'),
('trivia','What is the capital of The Gambia?','["Amsterdam", "Banjul", "Bissau", "Bishkek"]'::jsonb,'Banjul'),
('trivia','Which of these countries uses currency code GMD?','["The Gambia", "Iraq", "Malta", "Portugal"]'::jsonb,'The Gambia'),
('trivia','Which country has Tbilisi as its capital?','["Norway", "Georgia", "Hungary", "Liechtenstein"]'::jsonb,'Georgia'),
('trivia','What is the capital of Georgia?','["Tbilisi", "Georgetown", "Vientiane", "Nouméa"]'::jsonb,'Tbilisi'),
('trivia','Which of these countries uses currency code GEL?','["Ireland", "Isle of Man", "Puerto Rico", "Georgia"]'::jsonb,'Georgia'),
('trivia','Which country has Berlin as its capital?','["Germany", "Iceland", "Lithuania", "Oman"]'::jsonb,'Germany'),
('trivia','What is the capital of Germany?','["Port-au-Prince", "Riga", "Wellington", "Berlin"]'::jsonb,'Berlin'),
('trivia','Which country has Accra as its capital?','["India", "Luxembourg", "Pakistan", "Ghana"]'::jsonb,'Ghana'),
('trivia','What is the capital of Ghana?','["Beirut", "Managua", "Accra", "Tegucigalpa"]'::jsonb,'Accra'),
('trivia','Which of these countries uses currency code GHS?','["Réunion", "Ghana", "Italy", "Martinique"]'::jsonb,'Ghana'),
('trivia','Which country has Gibraltar as its capital?','["Republic of Macedonia", "Palau", "Gibraltar", "Indonesia"]'::jsonb,'Gibraltar'),
('trivia','What is the capital of Gibraltar?','["Niamey", "Gibraltar", "City of Victoria", "Maseru"]'::jsonb,'Gibraltar'),
('trivia','Which of these countries uses currency code GIP?','["Gibraltar", "Jamaica", "Mauritania", "Romania"]'::jsonb,'Gibraltar'),
('trivia','Which country has Athens as its capital?','["Panama", "Greece", "Iran", "Madagascar"]'::jsonb,'Greece'),
('trivia','What is the capital of Greece?','["Athens", "Budapest", "Monrovia", "Abuja"]'::jsonb,'Athens'),
('trivia','Which country has Nuuk as its capital?','["Greenland", "Iraq", "Malawi", "Papua New Guinea"]'::jsonb,'Greenland'),
('trivia','What is the capital of Greenland?','["Reykjavik", "Tripoli", "Alofi", "Nuuk"]'::jsonb,'Nuuk'),
('trivia','Which country has St. George''s as its capital?','["Ireland", "Malaysia", "Paraguay", "Grenada"]'::jsonb,'Grenada'),
('trivia','What is the capital of Grenada?','["Vaduz", "Kingston", "St. George''s", "New Delhi"]'::jsonb,'St. George''s'),
('trivia','Which country has Basse-Terre as its capital?','["Maldives", "Peru", "Guadeloupe", "Israel"]'::jsonb,'Guadeloupe'),
('trivia','What is the capital of Guadeloupe?','["Saipan", "Basse-Terre", "Jakarta", "Vilnius"]'::jsonb,'Basse-Terre'),
('trivia','Which country has Hagåtña as its capital?','["Philippines", "Guam", "Italy", "Mali"]'::jsonb,'Guam'),
('trivia','What is the capital of Guam?','["Hagåtña", "Tehran", "Luxembourg", "Oslo"]'::jsonb,'Hagåtña'),
('trivia','Which country has Guatemala City as its capital?','["Guatemala", "Jamaica", "Malta", "Pitcairn Islands"]'::jsonb,'Guatemala'),
('trivia','What is the capital of Guatemala?','["Baghdad", "Skopje", "Muscat", "Guatemala City"]'::jsonb,'Guatemala City'),
('trivia','Which of these countries uses currency code GTQ?','["Monaco", "Saint Pierre and Miquelon", "Guatemala", "Kiribati"]'::jsonb,'Guatemala'),
('trivia','Which country has St. Peter Port as its capital?','["Japan", "Isle of Man", "Poland", "Guernsey"]'::jsonb,'Guernsey'),
('trivia','What is the capital of Guernsey?','["Antananarivo", "Islamabad", "St. Peter Port", "Dublin"]'::jsonb,'St. Peter Port'),
('trivia','Which of these countries uses currency code GBP?','["Saint Vincent and the Grenadines", "Guernsey", "North Korea", "Mongolia"]'::jsonb,'Guernsey'),
('trivia','Which country has Conakry as its capital?','["Marshall Islands", "Portugal", "Guinea", "Jersey"]'::jsonb,'Guinea'),
('trivia','What is the capital of Guinea?','["Ngerulmud", "Conakry", "Jerusalem", "Lilongwe"]'::jsonb,'Conakry'),
('trivia','Which of these countries uses currency code GNF?','["Guinea", "South Korea", "Montserrat", "Samoa"]'::jsonb,'Guinea'),
('trivia','Which country has Bissau as its capital?','["Puerto Rico", "Guinea-Bissau", "Jordan", "Martinique"]'::jsonb,'Guinea-Bissau'),
('trivia','What is the capital of Guinea-Bissau?','["Bissau", "Rome", "Kuala Lumpur", "Panama City"]'::jsonb,'Bissau'),
('trivia','Which country has Georgetown as its capital?','["Guyana", "Kazakhstan", "Mauritania", "Qatar"]'::jsonb,'Guyana'),
('trivia','What is the capital of Guyana?','["Kingston", "Malé", "Port Moresby", "Georgetown"]'::jsonb,'Georgetown'),
('trivia','Which of these countries uses currency code GYD?','["Mozambique", "São Tomé and Príncipe", "Guyana", "Kyrgyzstan"]'::jsonb,'Guyana'),
('trivia','Which country has Port-au-Prince as its capital?','["Kenya", "Mauritius", "Réunion", "Haiti"]'::jsonb,'Haiti'),
('trivia','What is the capital of Haiti?','["Bamako", "Asunción", "Port-au-Prince", "Tokyo"]'::jsonb,'Port-au-Prince'),
('trivia','Which of these countries uses currency code HTG?','["Saudi Arabia", "Haiti", "Laos", "Namibia"]'::jsonb,'Haiti'),
('trivia','Which country has Tegucigalpa as its capital?','["Mayotte", "Romania", "Honduras", "Kiribati"]'::jsonb,'Honduras'),
('trivia','What is the capital of Honduras?','["Lima", "Tegucigalpa", "Saint Helier", "Valletta"]'::jsonb,'Tegucigalpa'),
('trivia','Which of these countries uses currency code HNL?','["Honduras", "Latvia", "Nauru", "Senegal"]'::jsonb,'Honduras'),
('trivia','Which country has City of Victoria as its capital?','["Russia", "Hong Kong", "North Korea", "Mexico"]'::jsonb,'Hong Kong'),
('trivia','What is the capital of Hong Kong?','["City of Victoria", "Amman", "Douglas", "Manila"]'::jsonb,'City of Victoria'),
('trivia','Which of these countries uses currency code HKD?','["Lebanon", "Nepal", "Serbia", "Hong Kong"]'::jsonb,'Hong Kong'),
('trivia','Which country has Budapest as its capital?','["Hungary", "South Korea", "Federated States of Micronesia", "Rwanda"]'::jsonb,'Hungary'),
('trivia','What is the capital of Hungary?','["Astana", "Majuro", "Adamstown", "Budapest"]'::jsonb,'Budapest'),
('trivia','Which of these countries uses currency code HUF?','["Netherlands", "Seychelles", "Hungary", "Lesotho"]'::jsonb,'Hungary'),
('trivia','Which country has Reykjavik as its capital?','["Kuwait", "Moldova", "Saint Helena", "Iceland"]'::jsonb,'Iceland'),
('trivia','What is the capital of Iceland?','["Fort-de-France", "Warsaw", "Reykjavik", "Nairobi"]'::jsonb,'Reykjavik'),
('trivia','Which of these countries uses currency code ISK?','["Sierra Leone", "Iceland", "Liberia", "New Caledonia"]'::jsonb,'Iceland'),
('trivia','Which country has New Delhi as its capital?','["Monaco", "Saint Kitts and Nevis", "India", "Kyrgyzstan"]'::jsonb,'India'),
('trivia','What is the capital of India?','["Lisbon", "New Delhi", "South Tarawa", "Nouakchott"]'::jsonb,'New Delhi'),
('trivia','Which of these countries uses currency code INR?','["India", "Libya", "New Zealand", "Singapore"]'::jsonb,'India'),
('trivia','Which country has Jakarta as its capital?','["Saint Lucia", "Indonesia", "Laos", "Mongolia"]'::jsonb,'Indonesia'),
('trivia','What is the capital of Indonesia?','["Jakarta", "Pyongyang", "Port Louis", "San Juan"]'::jsonb,'Jakarta'),
('trivia','Which of these countries uses currency code IDR?','["Liechtenstein", "Nicaragua", "Slovakia", "Indonesia"]'::jsonb,'Indonesia'),
('trivia','Which country has Tehran as its capital?','["Iran", "Latvia", "Montserrat", "Saint Pierre and Miquelon"]'::jsonb,'Iran'),
('trivia','What is the capital of Iran?','["Seoul", "Mamoudzou", "Doha", "Tehran"]'::jsonb,'Tehran'),
('trivia','Which of these countries uses currency code IRR?','["Niger", "Slovenia", "Iran", "Lithuania"]'::jsonb,'Iran'),
('trivia','Which country has Baghdad as its capital?','["Lebanon", "Morocco", "Saint Vincent and the Grenadines", "Iraq"]'::jsonb,'Iraq'),
('trivia','What is the capital of Iraq?','["Mexico City", "Saint-Denis", "Baghdad", "Kuwait City"]'::jsonb,'Baghdad'),
('trivia','Which of these countries uses currency code IQD?','["Solomon Islands", "Iraq", "Luxembourg", "Nigeria"]'::jsonb,'Iraq'),
('trivia','Which country has Dublin as its capital?','["Mozambique", "Samoa", "Ireland", "Lesotho"]'::jsonb,'Ireland'),
('trivia','What is the capital of Ireland?','["Bucharest", "Dublin", "Bishkek", "Palikir"]'::jsonb,'Dublin'),
('trivia','Which country has Jerusalem as its capital?','["San Marino", "Israel", "Liberia", "Namibia"]'::jsonb,'Israel'),
('trivia','What is the capital of Israel?','["Jerusalem", "Vientiane", "Chișinău", "Moscow"]'::jsonb,'Jerusalem'),
('trivia','Which of these countries uses currency code ILS?','["Madagascar", "Norfolk Island", "South Africa", "Israel"]'::jsonb,'Israel'),
('trivia','Which country has Rome as its capital?','["Italy", "Libya", "Nauru", "São Tomé and Príncipe"]'::jsonb,'Italy'),
('trivia','What is the capital of Italy?','["Riga", "Monaco", "Kigali", "Rome"]'::jsonb,'Rome'),
('trivia','Which country has Kingston as its capital?','["Liechtenstein", "Nepal", "Saudi Arabia", "Jamaica"]'::jsonb,'Jamaica'),
('trivia','What is the capital of Jamaica?','["Ulan Bator", "Jamestown", "Kingston", "Beirut"]'::jsonb,'Kingston'),
('trivia','Which of these countries uses currency code JMD?','["South Sudan", "Jamaica", "Malaysia", "Norway"]'::jsonb,'Jamaica'),
('trivia','Which country has Tokyo as its capital?','["Netherlands", "Senegal", "Japan", "Lithuania"]'::jsonb,'Japan'),
('trivia','What is the capital of Japan?','["Basseterre", "Tokyo", "Maseru", "Plymouth"]'::jsonb,'Tokyo'),
('trivia','Which of these countries uses currency code JPY?','["Japan", "Maldives", "Oman", "Spain"]'::jsonb,'Japan'),
('trivia','Which country has Saint Helier as its capital?','["Serbia", "Jersey", "Luxembourg", "New Caledonia"]'::jsonb,'Jersey'),
('trivia','What is the capital of Jersey?','["Saint Helier", "Monrovia", "Rabat", "Castries"]'::jsonb,'Saint Helier'),
('trivia','Which country has Amman as its capital?','["Jordan", "Republic of Macedonia", "New Zealand", "Seychelles"]'::jsonb,'Jordan'),
('trivia','What is the capital of Jordan?','["Tripoli", "Maputo", "Saint-Pierre", "Amman"]'::jsonb,'Amman'),
('trivia','Which of these countries uses currency code JOD?','["Palau", "Sudan", "Jordan", "Malta"]'::jsonb,'Jordan'),
('trivia','Which country has Astana as its capital?','["Madagascar", "Nicaragua", "Sierra Leone", "Kazakhstan"]'::jsonb,'Kazakhstan'),
('trivia','What is the capital of Kazakhstan?','["Windhoek", "Kingstown", "Astana", "Vaduz"]'::jsonb,'Astana'),
('trivia','Which of these countries uses currency code KZT?','["Suriname", "Kazakhstan", "Isle of Man", "Panama"]'::jsonb,'Kazakhstan'),
('trivia','Which country has Nairobi as its capital?','["Niger", "Singapore", "Kenya", "Malawi"]'::jsonb,'Kenya'),
('trivia','What is the capital of Kenya?','["Apia", "Nairobi", "Vilnius", "Yaren"]'::jsonb,'Nairobi'),
('trivia','Which of these countries uses currency code KES?','["Kenya", "Marshall Islands", "Papua New Guinea", "Svalbard and Jan Mayen"]'::jsonb,'Kenya'),
('trivia','Which country has South Tarawa as its capital?','["Slovakia", "Kiribati", "Malaysia", "Nigeria"]'::jsonb,'Kiribati'),
('trivia','What is the capital of Kiribati?','["South Tarawa", "Luxembourg", "Kathmandu", "City of San Marino"]'::jsonb,'South Tarawa'),
('trivia','Which country has Pyongyang as its capital?','["North Korea", "Maldives", "Niue", "Slovenia"]'::jsonb,'North Korea'),
('trivia','What is the capital of North Korea?','["Skopje", "Amsterdam", "São Tomé", "Pyongyang"]'::jsonb,'Pyongyang'),
('trivia','Which of these countries uses currency code KPW?','["Peru", "Sweden", "North Korea", "Mauritania"]'::jsonb,'North Korea'),
('trivia','Which country has Seoul as its capital?','["Mali", "Norfolk Island", "Solomon Islands", "South Korea"]'::jsonb,'South Korea'),
('trivia','What is the capital of South Korea?','["Nouméa", "Riyadh", "Seoul", "Antananarivo"]'::jsonb,'Seoul'),
('trivia','Which of these countries uses currency code KRW?','["Switzerland", "South Korea", "Mauritius", "Philippines"]'::jsonb,'South Korea'),
('trivia','Which country has Kuwait City as its capital?','["Northern Mariana Islands", "Somalia", "Kuwait", "Malta"]'::jsonb,'Kuwait'),
('trivia','What is the capital of Kuwait?','["Dakar", "Kuwait City", "Lilongwe", "Wellington"]'::jsonb,'Kuwait City'),
('trivia','Which of these countries uses currency code KWD?','["Kuwait", "Mayotte", "Pitcairn Islands", "Syria"]'::jsonb,'Kuwait'),
('trivia','Which country has Bishkek as its capital?','["South Africa", "Kyrgyzstan", "Isle of Man", "Norway"]'::jsonb,'Kyrgyzstan'),
('trivia','What is the capital of Kyrgyzstan?','["Bishkek", "Kuala Lumpur", "Managua", "Belgrade"]'::jsonb,'Bishkek'),
('trivia','Which of these countries uses currency code KGS?','["Mexico", "Poland", "Taiwan", "Kyrgyzstan"]'::jsonb,'Kyrgyzstan'),
('trivia','Which country has Vientiane as its capital?','["Laos", "Marshall Islands", "Oman", "South Georgia"]'::jsonb,'Laos'),
('trivia','What is the capital of Laos?','["Malé", "Niamey", "Victoria", "Vientiane"]'::jsonb,'Vientiane'),
('trivia','Which of these countries uses currency code LAK?','["Portugal", "Tajikistan", "Laos", "Federated States of Micronesia"]'::jsonb,'Laos'),
('trivia','Which country has Riga as its capital?','["Martinique", "Pakistan", "South Sudan", "Latvia"]'::jsonb,'Latvia'),
('trivia','What is the capital of Latvia?','["Abuja", "Freetown", "Riga", "Bamako"]'::jsonb,'Riga'),
('trivia','Which country has Beirut as its capital?','["Palau", "Spain", "Lebanon", "Mauritania"]'::jsonb,'Lebanon'),
('trivia','What is the capital of Lebanon?','["Singapore", "Beirut", "Valletta", "Alofi"]'::jsonb,'Beirut'),
('trivia','Which of these countries uses currency code LBP?','["Lebanon", "Monaco", "Qatar", "Thailand"]'::jsonb,'Lebanon'),
('trivia','Which country has Maseru as its capital?','["Sri Lanka", "Lesotho", "Mauritius", "Panama"]'::jsonb,'Lesotho'),
('trivia','What is the capital of Lesotho?','["Maseru", "Douglas", "Kingston", "Bratislava"]'::jsonb,'Maseru'),
('trivia','Which of these countries uses currency code LSL?','["Mongolia", "Réunion", "East Timor", "Lesotho"]'::jsonb,'Lesotho'),
('trivia','Which country has Monrovia as its capital?','["Liberia", "Mayotte", "Papua New Guinea", "Sudan"]'::jsonb,'Liberia'),
('trivia','What is the capital of Liberia?','["Majuro", "Saipan", "Ljubljana", "Monrovia"]'::jsonb,'Monrovia'),
('trivia','Which of these countries uses currency code LRD?','["Romania", "Togo", "Liberia", "Montserrat"]'::jsonb,'Liberia'),
('trivia','Which country has Tripoli as its capital?','["Mexico", "Paraguay", "Suriname", "Libya"]'::jsonb,'Libya'),
('trivia','What is the capital of Libya?','["Oslo", "Honiara", "Tripoli", "Fort-de-France"]'::jsonb,'Tripoli'),
('trivia','Which of these countries uses currency code LYD?','["Tokelau", "Libya", "Morocco", "Russia"]'::jsonb,'Libya'),
('trivia','Which country has Vaduz as its capital?','["Peru", "Svalbard and Jan Mayen", "Liechtenstein", "Federated States of Micronesia"]'::jsonb,'Liechtenstein'),
('trivia','What is the capital of Liechtenstein?','["Mogadishu", "Vaduz", "Nouakchott", "Muscat"]'::jsonb,'Vaduz'),
('trivia','Which of these countries uses currency code CHF?','["Liechtenstein", "Mozambique", "Rwanda", "Tonga"]'::jsonb,'Liechtenstein'),
('trivia','Which country has Vilnius as its capital?','["Swaziland", "Lithuania", "Moldova", "Philippines"]'::jsonb,'Lithuania'),
('trivia','What is the capital of Lithuania?','["Vilnius", "Port Louis", "Islamabad", "Pretoria"]'::jsonb,'Vilnius'),
('trivia','Which country has Luxembourg as its capital?','["Luxembourg", "Monaco", "Pitcairn Islands", "Sweden"]'::jsonb,'Luxembourg'),
('trivia','What is the capital of Luxembourg?','["Mamoudzou", "Ngerulmud", "King Edward Point", "Luxembourg"]'::jsonb,'Luxembourg'),
('trivia','Which country has Skopje as its capital?','["Mongolia", "Poland", "Switzerland", "Republic of Macedonia"]'::jsonb,'Republic of Macedonia'),
('trivia','What is the capital of Republic of Macedonia?','["Panama City", "Juba", "Skopje", "Mexico City"]'::jsonb,'Skopje'),
('trivia','Which of these countries uses currency code MKD?','["Turkey", "Republic of Macedonia", "Nepal", "Saint Lucia"]'::jsonb,'Republic of Macedonia'),
('trivia','Which country has Antananarivo as its capital?','["Portugal", "Syria", "Madagascar", "Montserrat"]'::jsonb,'Madagascar'),
('trivia','What is the capital of Madagascar?','["Madrid", "Antananarivo", "Palikir", "Port Moresby"]'::jsonb,'Antananarivo'),
('trivia','Which of these countries uses currency code MGA?','["Madagascar", "Netherlands", "Saint Pierre and Miquelon", "Turkmenistan"]'::jsonb,'Madagascar'),
('trivia','Which country has Lilongwe as its capital?','["Taiwan", "Malawi", "Morocco", "Puerto Rico"]'::jsonb,'Malawi'),
('trivia','What is the capital of Malawi?','["Lilongwe", "Chișinău", "Asunción", "Colombo"]'::jsonb,'Lilongwe'),
('trivia','Which of these countries uses currency code MWK?','["New Caledonia", "Saint Vincent and the Grenadines", "Tuvalu", "Malawi"]'::jsonb,'Malawi'),
('trivia','Which country has Kuala Lumpur as its capital?','["Malaysia", "Mozambique", "Qatar", "Tajikistan"]'::jsonb,'Malaysia'),
('trivia','What is the capital of Malaysia?','["Monaco", "Lima", "Khartoum", "Kuala Lumpur"]'::jsonb,'Kuala Lumpur'),
('trivia','Which of these countries uses currency code MYR?','["Samoa", "Uganda", "Malaysia", "New Zealand"]'::jsonb,'Malaysia'),
('trivia','Which country has Malé as its capital?','["Namibia", "Réunion", "Tanzania", "Maldives"]'::jsonb,'Maldives'),
('trivia','What is the capital of Maldives?','["Manila", "Paramaribo", "Malé", "Ulan Bator"]'::jsonb,'Malé'),
('trivia','Which of these countries uses currency code MVR?','["Ukraine", "Maldives", "Nicaragua", "San Marino"]'::jsonb,'Maldives'),
('trivia','Which country has Bamako as its capital?','["Romania", "Thailand", "Mali", "Nauru"]'::jsonb,'Mali'),
('trivia','What is the capital of Mali?','["Longyearbyen", "Bamako", "Plymouth", "Adamstown"]'::jsonb,'Bamako'),
('trivia','Which country has Valletta as its capital?','["East Timor", "Malta", "Nepal", "Russia"]'::jsonb,'Malta'),
('trivia','What is the capital of Malta?','["Valletta", "Rabat", "Warsaw", "Lobamba"]'::jsonb,'Valletta'),
('trivia','Which country has Douglas as its capital?','["Isle of Man", "Netherlands", "Rwanda", "Togo"]'::jsonb,'Isle of Man'),
('trivia','What is the capital of Isle of Man?','["Maputo", "Lisbon", "Stockholm", "Douglas"]'::jsonb,'Douglas'),
('trivia','Which country has Majuro as its capital?','["New Caledonia", "Saint Helena", "Tokelau", "Marshall Islands"]'::jsonb,'Marshall Islands'),
('trivia','What is the capital of Marshall Islands?','["San Juan", "Bern", "Majuro", "Windhoek"]'::jsonb,'Majuro'),
('trivia','Which country has Fort-de-France as its capital?','["Saint Kitts and Nevis", "Tonga", "Martinique", "New Zealand"]'::jsonb,'Martinique'),
('trivia','What is the capital of Martinique?','["Damascus", "Fort-de-France", "Yaren", "Doha"]'::jsonb,'Fort-de-France'),
('trivia','Which country has Nouakchott as its capital?','["Trinidad and Tobago", "Mauritania", "Nicaragua", "Saint Lucia"]'::jsonb,'Mauritania'),
('trivia','What is the capital of Mauritania?','["Nouakchott", "Kathmandu", "Saint-Denis", "Taipei"]'::jsonb,'Nouakchott'),
('trivia','Which of these countries uses currency code MRO?','["Norway", "Sierra Leone", "Vanuatu", "Mauritania"]'::jsonb,'Mauritania'),
('trivia','Which country has Port Louis as its capital?','["Mauritius", "Niger", "Saint Pierre and Miquelon", "Tunisia"]'::jsonb,'Mauritius'),
('trivia','What is the capital of Mauritius?','["Amsterdam", "Bucharest", "Dushanbe", "Port Louis"]'::jsonb,'Port Louis'),
('trivia','Which of these countries uses currency code MUR?','["Singapore", "Venezuela", "Mauritius", "Oman"]'::jsonb,'Mauritius'),
('trivia','Which country has Mamoudzou as its capital?','["Nigeria", "Saint Vincent and the Grenadines", "Turkey", "Mayotte"]'::jsonb,'Mayotte'),
('trivia','What is the capital of Mayotte?','["Moscow", "Dodoma", "Mamoudzou", "Nouméa"]'::jsonb,'Mamoudzou'),
('trivia','Which country has Mexico City as its capital?','["Samoa", "Turkmenistan", "Mexico", "Niue"]'::jsonb,'Mexico'),
('trivia','What is the capital of Mexico?','["Bangkok", "Mexico City", "Wellington", "Kigali"]'::jsonb,'Mexico City'),
('trivia','Which of these countries uses currency code MXN?','["Mexico", "Palau", "Slovenia", "Wallis and Futuna"]'::jsonb,'Mexico'),
('trivia','Which country has Palikir as its capital?','["Tuvalu", "Federated States of Micronesia", "Norfolk Island", "San Marino"]'::jsonb,'Federated States of Micronesia'),
('trivia','What is the capital of Federated States of Micronesia?','["Palikir", "Managua", "Jamestown", "Dili"]'::jsonb,'Palikir'),
('trivia','Which country has Chișinău as its capital?','["Moldova", "Northern Mariana Islands", "São Tomé and Príncipe", "Uganda"]'::jsonb,'Moldova'),
('trivia','What is the capital of Moldova?','["Niamey", "Basseterre", "Lomé", "Chișinău"]'::jsonb,'Chișinău'),
('trivia','Which of these countries uses currency code MDL?','["Somalia", "Yemen", "Moldova", "Papua New Guinea"]'::jsonb,'Moldova'),
('trivia','Which country has Monaco as its capital?','["Norway", "Saudi Arabia", "Ukraine", "Monaco"]'::jsonb,'Monaco'),
('trivia','What is the capital of Monaco?','["Castries", "Fakaofo", "Monaco", "Abuja"]'::jsonb,'Monaco'),
('trivia','Which country has Ulan Bator as its capital?','["Senegal", "United Arab Emirates", "Mongolia", "Oman"]'::jsonb,'Mongolia'),
('trivia','What is the capital of Mongolia?','["Nuku''alofa", "Ulan Bator", "Alofi", "Saint-Pierre"]'::jsonb,'Ulan Bator'),
('trivia','Which of these countries uses currency code MNT?','["Mongolia", "Peru", "South Georgia", "Zimbabwe"]'::jsonb,'Mongolia'),
('trivia','Which country has Plymouth as its capital?','["United Kingdom", "Montserrat", "Pakistan", "Serbia"]'::jsonb,'Montserrat'),
('trivia','What is the capital of Montserrat?','["Plymouth", "Kingston", "Kingstown", "Port of Spain"]'::jsonb,'Plymouth'),
('trivia','Which country has Rabat as its capital?','["Morocco", "Palau", "Seychelles", "United States"]'::jsonb,'Morocco'),
('trivia','What is the capital of Morocco?','["Saipan", "Apia", "Tunis", "Rabat"]'::jsonb,'Rabat'),
('trivia','Which of these countries uses currency code MAD?','["Spain", "Albania", "Morocco", "Pitcairn Islands"]'::jsonb,'Morocco'),
('trivia','Which country has Maputo as its capital?','["Panama", "Sierra Leone", "Uruguay", "Mozambique"]'::jsonb,'Mozambique'),
('trivia','What is the capital of Mozambique?','["City of San Marino", "Ankara", "Maputo", "Oslo"]'::jsonb,'Maputo'),
('trivia','Which of these countries uses currency code MZN?','["Algeria", "Mozambique", "Poland", "Sri Lanka"]'::jsonb,'Mozambique'),
('trivia','Which country has Windhoek as its capital?','["Singapore", "Uzbekistan", "Namibia", "Papua New Guinea"]'::jsonb,'Namibia'),
('trivia','What is the capital of Namibia?','["Ashgabat", "Windhoek", "Muscat", "São Tomé"]'::jsonb,'Windhoek'),
('trivia','Which of these countries uses currency code NAD?','["Namibia", "Portugal", "Sudan", "American Samoa"]'::jsonb,'Namibia'),
('trivia','Which country has Yaren as its capital?','["Vanuatu", "Nauru", "Paraguay", "Slovakia"]'::jsonb,'Nauru'),
('trivia','What is the capital of Nauru?','["Yaren", "Islamabad", "Riyadh", "Funafuti"]'::jsonb,'Yaren'),
('trivia','Which country has Kathmandu as its capital?','["Nepal", "Peru", "Slovenia", "Venezuela"]'::jsonb,'Nepal'),
('trivia','What is the capital of Nepal?','["Ngerulmud", "Dakar", "Kampala", "Kathmandu"]'::jsonb,'Kathmandu'),
('trivia','Which of these countries uses currency code NPR?','["Svalbard and Jan Mayen", "Anguilla", "Nepal", "Qatar"]'::jsonb,'Nepal'),
('trivia','Which country has Amsterdam as its capital?','["Philippines", "Solomon Islands", "Vietnam", "Netherlands"]'::jsonb,'Netherlands'),
('trivia','What is the capital of Netherlands?','["Belgrade", "Kiev", "Amsterdam", "Panama City"]'::jsonb,'Amsterdam'),
('trivia','Which country has Nouméa as its capital?','["Somalia", "Wallis and Futuna", "New Caledonia", "Pitcairn Islands"]'::jsonb,'New Caledonia'),
('trivia','What is the capital of New Caledonia?','["Abu Dhabi", "Nouméa", "Port Moresby", "Victoria"]'::jsonb,'Nouméa'),
('trivia','Which country has Wellington as its capital?','["Western Sahara", "New Zealand", "Poland", "South Africa"]'::jsonb,'New Zealand'),
('trivia','What is the capital of New Zealand?','["Wellington", "Asunción", "Freetown", "London"]'::jsonb,'Wellington'),
('trivia','Which country has Managua as its capital?','["Nicaragua", "Portugal", "South Georgia", "Yemen"]'::jsonb,'Nicaragua'),
('trivia','What is the capital of Nicaragua?','["Lima", "Singapore", "Washington D.C.", "Managua"]'::jsonb,'Managua'),
('trivia','Which of these countries uses currency code NIO?','["Syria", "Aruba", "Nicaragua", "Rwanda"]'::jsonb,'Nicaragua'),
('trivia','Which country has Niamey as its capital?','["Puerto Rico", "South Sudan", "Zambia", "Niger"]'::jsonb,'Niger'),
('trivia','What is the capital of Niger?','["Bratislava", "Montevideo", "Niamey", "Manila"]'::jsonb,'Niamey'),
('trivia','Which country has Abuja as its capital?','["Spain", "Zimbabwe", "Nigeria", "Qatar"]'::jsonb,'Nigeria'),
('trivia','What is the capital of Nigeria?','["Tashkent", "Abuja", "Adamstown", "Ljubljana"]'::jsonb,'Abuja'),
('trivia','Which of these countries uses currency code NGN?','["Nigeria", "Saint Kitts and Nevis", "Tajikistan", "Austria"]'::jsonb,'Nigeria'),
('trivia','Which country has Alofi as its capital?','["Afghanistan", "Niue", "Réunion", "Sri Lanka"]'::jsonb,'Niue'),
('trivia','What is the capital of Niue?','["Alofi", "Warsaw", "Honiara", "Port Vila"]'::jsonb,'Alofi'),
('trivia','What is the capital of Norfolk Island?','["Lisbon", "Mogadishu", "Caracas", "Kingston"]'::jsonb,'Kingston'),
('trivia','Which country has Saipan as its capital?','["Russia", "Suriname", "Algeria", "Northern Mariana Islands"]'::jsonb,'Northern Mariana Islands'),
('trivia','What is the capital of Northern Mariana Islands?','["Pretoria", "Hanoi", "Saipan", "San Juan"]'::jsonb,'Saipan'),
('trivia','Which country has Oslo as its capital?','["Svalbard and Jan Mayen", "American Samoa", "Norway", "Rwanda"]'::jsonb,'Norway'),
('trivia','What is the capital of Norway?','["Mata-Utu", "Oslo", "Doha", "King Edward Point"]'::jsonb,'Oslo'),
('trivia','Which of these countries uses currency code NOK?','["Norway", "Samoa", "Togo", "Bangladesh"]'::jsonb,'Norway'),
('trivia','Which country has Muscat as its capital?','["Angola", "Oman", "Saint Helena", "Swaziland"]'::jsonb,'Oman'),
('trivia','What is the capital of Oman?','["Muscat", "Saint-Denis", "Juba", "El Aaiún"]'::jsonb,'Muscat'),
('trivia','Which of these countries uses currency code OMR?','["San Marino", "Tokelau", "Barbados", "Oman"]'::jsonb,'Oman'),
('trivia','Which country has Islamabad as its capital?','["Pakistan", "Saint Kitts and Nevis", "Sweden", "Anguilla"]'::jsonb,'Pakistan'),
('trivia','What is the capital of Pakistan?','["Bucharest", "Madrid", "Sana''a", "Islamabad"]'::jsonb,'Islamabad'),
('trivia','Which of these countries uses currency code PKR?','["Tonga", "Belarus", "Pakistan", "São Tomé and Príncipe"]'::jsonb,'Pakistan'),
('trivia','Which country has Ngerulmud as its capital?','["Saint Lucia", "Switzerland", "Antigua and Barbuda", "Palau"]'::jsonb,'Palau'),
('trivia','What is the capital of Palau?','["Colombo", "Lusaka", "Ngerulmud", "Moscow"]'::jsonb,'Ngerulmud'),
('trivia','Which country has Panama City as its capital?','["Syria", "Argentina", "Panama", "Saint Pierre and Miquelon"]'::jsonb,'Panama'),
('trivia','What is the capital of Panama?','["Harare", "Panama City", "Kigali", "Khartoum"]'::jsonb,'Panama City'),
('trivia','Which of these countries uses currency code PAB?','["Panama", "Senegal", "Tunisia", "Belize"]'::jsonb,'Panama'),
('trivia','Which country has Port Moresby as its capital?','["Armenia", "Papua New Guinea", "Saint Vincent and the Grenadines", "Taiwan"]'::jsonb,'Papua New Guinea'),
('trivia','What is the capital of Papua New Guinea?','["Port Moresby", "Jamestown", "Paramaribo", "Kabul"]'::jsonb,'Port Moresby'),
('trivia','Which of these countries uses currency code PGK?','["Serbia", "Turkey", "Benin", "Papua New Guinea"]'::jsonb,'Papua New Guinea'),
('trivia','Which country has Asunción as its capital?','["Paraguay", "Samoa", "Tajikistan", "Aruba"]'::jsonb,'Paraguay'),
('trivia','What is the capital of Paraguay?','["Basseterre", "Longyearbyen", "Tirana", "Asunción"]'::jsonb,'Asunción'),
('trivia','Which of these countries uses currency code PYG?','["Turkmenistan", "Bermuda", "Paraguay", "Seychelles"]'::jsonb,'Paraguay'),
('trivia','Which country has Lima as its capital?','["San Marino", "Tanzania", "Australia", "Peru"]'::jsonb,'Peru'),
('trivia','What is the capital of Peru?','["Lobamba", "Algiers", "Lima", "Castries"]'::jsonb,'Lima'),
('trivia','Which of these countries uses currency code PEN?','["Bhutan", "Peru", "Sierra Leone", "Tuvalu"]'::jsonb,'Peru'),
('trivia','Which country has Manila as its capital?','["Thailand", "Austria", "Philippines", "São Tomé and Príncipe"]'::jsonb,'Philippines'),
('trivia','What is the capital of Philippines?','["Pago Pago", "Manila", "Saint-Pierre", "Stockholm"]'::jsonb,'Manila'),
('trivia','Which of these countries uses currency code PHP?','["Philippines", "Singapore", "Uganda", "Bolivia"]'::jsonb,'Philippines'),
('trivia','Which country has Adamstown as its capital?','["Azerbaijan", "Pitcairn Islands", "Saudi Arabia", "East Timor"]'::jsonb,'Pitcairn Islands'),
('trivia','What is the capital of Pitcairn Islands?','["Adamstown", "Kingstown", "Bern", "Luanda"]'::jsonb,'Adamstown'),
('trivia','Which country has Warsaw as its capital?','["Poland", "Senegal", "Togo", "The Bahamas"]'::jsonb,'Poland'),
('trivia','What is the capital of Poland?','["Apia", "Damascus", "The Valley", "Warsaw"]'::jsonb,'Warsaw'),
('trivia','Which of these countries uses currency code PLN?','["United Arab Emirates", "Botswana", "Poland", "Slovenia"]'::jsonb,'Poland'),
('trivia','Which country has Lisbon as its capital?','["Serbia", "Tokelau", "Bahrain", "Portugal"]'::jsonb,'Portugal'),
('trivia','What is the capital of Portugal?','["Taipei", "Saint John''s", "Lisbon", "City of San Marino"]'::jsonb,'Lisbon'),
('trivia','Which country has San Juan as its capital?','["Tonga", "Bangladesh", "Puerto Rico", "Seychelles"]'::jsonb,'Puerto Rico'),
('trivia','What is the capital of Puerto Rico?','["Buenos Aires", "San Juan", "São Tomé", "Dushanbe"]'::jsonb,'San Juan'),
('trivia','Which country has Doha as its capital?','["Barbados", "Qatar", "Sierra Leone", "Trinidad and Tobago"]'::jsonb,'Qatar'),
('trivia','What is the capital of Qatar?','["Doha", "Riyadh", "Dodoma", "Yerevan"]'::jsonb,'Doha'),
('trivia','Which of these countries uses currency code QAR?','["South Africa", "Uruguay", "Brunei", "Qatar"]'::jsonb,'Qatar'),
('trivia','Which country has Saint-Denis as its capital?','["Réunion", "Singapore", "Tunisia", "Belarus"]'::jsonb,'Réunion'),
('trivia','What is the capital of Réunion?','["Dakar", "Bangkok", "Oranjestad", "Saint-Denis"]'::jsonb,'Saint-Denis'),
('trivia','Which country has Bucharest as its capital?','["Slovakia", "Turkey", "Belgium", "Romania"]'::jsonb,'Romania'),
('trivia','What is the capital of Romania?','["Dili", "Canberra", "Bucharest", "Belgrade"]'::jsonb,'Bucharest'),
('trivia','Which of these countries uses currency code RON?','["Burkina Faso", "Romania", "South Sudan", "Vanuatu"]'::jsonb,'Romania'),
('trivia','Which country has Moscow as its capital?','["Turkmenistan", "Belize", "Russia", "Slovenia"]'::jsonb,'Russia'),
('trivia','What is the capital of Russia?','["Vienna", "Moscow", "Victoria", "Lomé"]'::jsonb,'Moscow'),
('trivia','Which of these countries uses currency code RUB?','["Russia", "Spain", "Venezuela", "Burundi"]'::jsonb,'Russia'),
('trivia','Which country has Kigali as its capital?','["Benin", "Rwanda", "Solomon Islands", "Tuvalu"]'::jsonb,'Rwanda'),
('trivia','What is the capital of Rwanda?','["Kigali", "Freetown", "Fakaofo", "Baku"]'::jsonb,'Kigali'),
('trivia','Which of these countries uses currency code RWF?','["Sri Lanka", "Vietnam", "Cambodia", "Rwanda"]'::jsonb,'Rwanda'),
('trivia','Which country has Jamestown as its capital?','["Saint Helena", "Somalia", "Uganda", "Bermuda"]'::jsonb,'Saint Helena'),
('trivia','What is the capital of Saint Helena?','["Singapore", "Nuku''alofa", "Nassau", "Jamestown"]'::jsonb,'Jamestown'),
('trivia','Which of these countries uses currency code SHP?','["Wallis and Futuna", "Cameroon", "Saint Helena", "Sudan"]'::jsonb,'Saint Helena'),
('trivia','Which country has Basseterre as its capital?','["South Africa", "Ukraine", "Bhutan", "Saint Kitts and Nevis"]'::jsonb,'Saint Kitts and Nevis'),
('trivia','What is the capital of Saint Kitts and Nevis?','["Port of Spain", "Manama", "Basseterre", "Bratislava"]'::jsonb,'Basseterre'),
('trivia','Which country has Castries as its capital?','["United Arab Emirates", "Bolivia", "Saint Lucia", "South Georgia"]'::jsonb,'Saint Lucia'),
('trivia','What is the capital of Saint Lucia?','["Dhaka", "Castries", "Ljubljana", "Tunis"]'::jsonb,'Castries'),
('trivia','Which country has Saint-Pierre as its capital?','["Bosnia and Herzegovina", "Saint Pierre and Miquelon", "South Sudan", "United Kingdom"]'::jsonb,'Saint Pierre and Miquelon'),
('trivia','What is the capital of Saint Pierre and Miquelon?','["Saint-Pierre", "Honiara", "Ankara", "Bridgetown"]'::jsonb,'Saint-Pierre'),
('trivia','Which country has Kingstown as its capital?','["Saint Vincent and the Grenadines", "Spain", "United States", "Botswana"]'::jsonb,'Saint Vincent and the Grenadines'),
('trivia','What is the capital of Saint Vincent and the Grenadines?','["Mogadishu", "Ashgabat", "Minsk", "Kingstown"]'::jsonb,'Kingstown'),
('trivia','Which country has Apia as its capital?','["Sri Lanka", "Uruguay", "Brazil", "Samoa"]'::jsonb,'Samoa'),
('trivia','What is the capital of Samoa?','["Funafuti", "Brussels", "Apia", "Pretoria"]'::jsonb,'Apia'),
('trivia','Which of these countries uses currency code WST?','["Chad", "Samoa", "Switzerland", "Afghanistan"]'::jsonb,'Samoa'),
('trivia','Which country has City of San Marino as its capital?','["Uzbekistan", "British Indian Ocean Territory", "San Marino", "Sudan"]'::jsonb,'San Marino'),
('trivia','What is the capital of San Marino?','["Belmopan", "City of San Marino", "King Edward Point", "Kampala"]'::jsonb,'City of San Marino'),
('trivia','Which country has São Tomé as its capital?','["Brunei", "São Tomé and Príncipe", "Suriname", "Vanuatu"]'::jsonb,'São Tomé and Príncipe'),
('trivia','What is the capital of São Tomé and Príncipe?','["São Tomé", "Juba", "Kiev", "Porto-Novo"]'::jsonb,'São Tomé'),
('trivia','Which of these countries uses currency code STD?','["Taiwan", "Algeria", "China", "São Tomé and Príncipe"]'::jsonb,'São Tomé and Príncipe'),
('trivia','Which country has Riyadh as its capital?','["Saudi Arabia", "Svalbard and Jan Mayen", "Venezuela", "Bulgaria"]'::jsonb,'Saudi Arabia'),
('trivia','What is the capital of Saudi Arabia?','["Madrid", "Abu Dhabi", "Hamilton", "Riyadh"]'::jsonb,'Riyadh'),
('trivia','Which of these countries uses currency code SAR?','["American Samoa", "Christmas Island", "Saudi Arabia", "Tajikistan"]'::jsonb,'Saudi Arabia'),
('trivia','Which country has Dakar as its capital?','["Swaziland", "Vietnam", "Burkina Faso", "Senegal"]'::jsonb,'Senegal'),
('trivia','What is the capital of Senegal?','["London", "Thimphu", "Dakar", "Colombo"]'::jsonb,'Dakar'),
('trivia','Which country has Belgrade as its capital?','["Wallis and Futuna", "Burundi", "Serbia", "Sweden"]'::jsonb,'Serbia'),
('trivia','What is the capital of Serbia?','["Sucre", "Belgrade", "Khartoum", "Washington D.C."]'::jsonb,'Belgrade'),
('trivia','Which of these countries uses currency code RSD?','["Serbia", "Thailand", "Anguilla", "Colombia"]'::jsonb,'Serbia'),
('trivia','Which country has Victoria as its capital?','["Cambodia", "Seychelles", "Switzerland", "Western Sahara"]'::jsonb,'Seychelles'),
('trivia','What is the capital of Seychelles?','["Victoria", "Paramaribo", "Montevideo", "Sarajevo"]'::jsonb,'Victoria'),
('trivia','Which of these countries uses currency code SCR?','["East Timor", "Antigua and Barbuda", "Comoros", "Seychelles"]'::jsonb,'Seychelles'),
('trivia','Which country has Freetown as its capital?','["Sierra Leone", "Syria", "Yemen", "Cameroon"]'::jsonb,'Sierra Leone'),
('trivia','What is the capital of Sierra Leone?','["Longyearbyen", "Tashkent", "Gaborone", "Freetown"]'::jsonb,'Freetown'),
('trivia','Which of these countries uses currency code SLL?','["Argentina", "Republic of the Congo", "Sierra Leone", "Togo"]'::jsonb,'Sierra Leone'),
('trivia','Which country has Singapore as its capital?','["Taiwan", "Zambia", "Canada", "Singapore"]'::jsonb,'Singapore'),
('trivia','What is the capital of Singapore?','["Port Vila", "Brasília", "Singapore", "Lobamba"]'::jsonb,'Singapore'),
('trivia','Which of these countries uses currency code SGD?','["Democratic Republic of the Congo", "Singapore", "Tokelau", "Armenia"]'::jsonb,'Singapore'),
('trivia','Which country has Bratislava as its capital?','["Zimbabwe", "Cape Verde", "Slovakia", "Tajikistan"]'::jsonb,'Slovakia'),
('trivia','What is the capital of Slovakia?','["Diego Garcia", "Bratislava", "Stockholm", "Caracas"]'::jsonb,'Bratislava'),
('trivia','Which country has Ljubljana as its capital?','["Cayman Islands", "Slovenia", "Tanzania", "Afghanistan"]'::jsonb,'Slovenia'),
('trivia','What is the capital of Slovenia?','["Ljubljana", "Bern", "Hanoi", "Bandar Seri Begawan"]'::jsonb,'Ljubljana'),
('trivia','Which country has Honiara as its capital?','["Solomon Islands", "Thailand", "Albania", "Central African Republic"]'::jsonb,'Solomon Islands'),
('trivia','What is the capital of Solomon Islands?','["Damascus", "Mata-Utu", "Sofia", "Honiara"]'::jsonb,'Honiara'),
('trivia','Which of these countries uses currency code SBD?','["Austria", "Ivory Coast", "Solomon Islands", "Tunisia"]'::jsonb,'Solomon Islands'),
('trivia','Which country has Mogadishu as its capital?','["East Timor", "Algeria", "Chad", "Somalia"]'::jsonb,'Somalia'),
('trivia','What is the capital of Somalia?','["El Aaiún", "Ouagadougou", "Mogadishu", "Taipei"]'::jsonb,'Mogadishu'),
('trivia','Which of these countries uses currency code SOS?','["Croatia", "Somalia", "Turkey", "Azerbaijan"]'::jsonb,'Somalia'),
('trivia','Which country has Pretoria as its capital?','["American Samoa", "Chile", "South Africa", "Togo"]'::jsonb,'South Africa'),
('trivia','What is the capital of South Africa?','["Bujumbura", "Pretoria", "Dushanbe", "Sana''a"]'::jsonb,'Pretoria'),
('trivia','Which of these countries uses currency code ZAR?','["South Africa", "Turkmenistan", "The Bahamas", "Cuba"]'::jsonb,'South Africa'),
('trivia','Which country has King Edward Point as its capital?','["China", "South Georgia", "Tokelau", "Angola"]'::jsonb,'South Georgia'),
('trivia','What is the capital of South Georgia?','["King Edward Point", "Dodoma", "Lusaka", "Phnom Penh"]'::jsonb,'King Edward Point'),
('trivia','Which country has Juba as its capital?','["South Sudan", "Tonga", "Anguilla", "Christmas Island"]'::jsonb,'South Sudan'),
('trivia','What is the capital of South Sudan?','["Bangkok", "Harare", "Yaoundé", "Juba"]'::jsonb,'Juba'),
('trivia','Which of these countries uses currency code SSP?','["Bangladesh", "Czech Republic", "South Sudan", "Uganda"]'::jsonb,'South Sudan'),
('trivia','Which country has Madrid as its capital?','["Trinidad and Tobago", "Antigua and Barbuda", "Cocos (Keeling) Islands", "Spain"]'::jsonb,'Spain'),
('trivia','What is the capital of Spain?','["Kabul", "Ottawa", "Madrid", "Dili"]'::jsonb,'Madrid'),
('trivia','Which country has Colombo as its capital?','["Argentina", "Colombia", "Sri Lanka", "Tunisia"]'::jsonb,'Sri Lanka'),
('trivia','What is the capital of Sri Lanka?','["Praia", "Colombo", "Lomé", "Tirana"]'::jsonb,'Colombo'),
('trivia','Which of these countries uses currency code LKR?','["Sri Lanka", "United Arab Emirates", "Belarus", "Djibouti"]'::jsonb,'Sri Lanka'),
('trivia','Which country has Khartoum as its capital?','["Comoros", "Sudan", "Turkey", "Armenia"]'::jsonb,'Sudan'),
('trivia','What is the capital of Sudan?','["Khartoum", "Fakaofo", "Algiers", "George Town"]'::jsonb,'Khartoum'),
('trivia','Which of these countries uses currency code SDG?','["United Kingdom", "Belgium", "Dominica", "Sudan"]'::jsonb,'Sudan'),
('trivia','Which country has Paramaribo as its capital?','["Suriname", "Turkmenistan", "Aruba", "Republic of the Congo"]'::jsonb,'Suriname'),
('trivia','What is the capital of Suriname?','["Nuku''alofa", "Pago Pago", "Bangui", "Paramaribo"]'::jsonb,'Paramaribo'),
('trivia','Which of these countries uses currency code SRD?','["Belize", "Dominican Republic", "Suriname", "United States"]'::jsonb,'Suriname'),
('trivia','Which country has Longyearbyen as its capital?','["Tuvalu", "Australia", "Democratic Republic of the Congo", "Svalbard and Jan Mayen"]'::jsonb,'Svalbard and Jan Mayen'),
('trivia','What is the capital of Svalbard and Jan Mayen?','["Luanda", "N''Djamena", "Longyearbyen", "Port of Spain"]'::jsonb,'Longyearbyen'),
('trivia','Which country has Lobamba as its capital?','["Austria", "Cook Islands", "Swaziland", "Uganda"]'::jsonb,'Swaziland'),
('trivia','What is the capital of Swaziland?','["Santiago", "Lobamba", "Tunis", "The Valley"]'::jsonb,'Lobamba'),
('trivia','Which of these countries uses currency code SZL?','["Swaziland", "Uzbekistan", "Bermuda", "Egypt"]'::jsonb,'Swaziland'),
('trivia','Which country has Stockholm as its capital?','["Costa Rica", "Sweden", "Ukraine", "Azerbaijan"]'::jsonb,'Sweden'),
('trivia','What is the capital of Sweden?','["Stockholm", "Ankara", "Saint John''s", "Beijing"]'::jsonb,'Stockholm'),
('trivia','Which of these countries uses currency code SEK?','["Vanuatu", "Bhutan", "El Salvador", "Sweden"]'::jsonb,'Sweden'),
('trivia','Which country has Bern as its capital?','["Switzerland", "United Arab Emirates", "The Bahamas", "Ivory Coast"]'::jsonb,'Switzerland'),
('trivia','What is the capital of Switzerland?','["Ashgabat", "Buenos Aires", "Flying Fish Cove", "Bern"]'::jsonb,'Bern'),
('trivia','Which of these countries uses currency code CHE?','["Bolivia", "Equatorial Guinea", "Switzerland", "Venezuela"]'::jsonb,'Switzerland'),
('trivia','Which country has Damascus as its capital?','["United Kingdom", "Bahrain", "Croatia", "Syria"]'::jsonb,'Syria'),
('trivia','What is the capital of Syria?','["Yerevan", "West Island", "Damascus", "Funafuti"]'::jsonb,'Damascus'),
('trivia','Which of these countries uses currency code SYP?','["Eritrea", "Syria", "Vietnam", "Bosnia and Herzegovina"]'::jsonb,'Syria'),
('trivia','Which country has Taipei as its capital?','["Bangladesh", "Cuba", "Taiwan", "United States"]'::jsonb,'Taiwan'),
('trivia','What is the capital of Taiwan?','["Bogotá", "Taipei", "Kampala", "Oranjestad"]'::jsonb,'Taipei'),
('trivia','Which of these countries uses currency code TWD?','["Taiwan", "Wallis and Futuna", "Botswana", "Estonia"]'::jsonb,'Taiwan'),
('trivia','Which country has Dushanbe as its capital?','["Cyprus", "Tajikistan", "Uruguay", "Barbados"]'::jsonb,'Tajikistan'),
('trivia','What is the capital of Tajikistan?','["Dushanbe", "Kiev", "Canberra", "Moroni"]'::jsonb,'Dushanbe'),
('trivia','Which of these countries uses currency code TJS?','["Western Sahara", "Brazil", "Ethiopia", "Tajikistan"]'::jsonb,'Tajikistan'),
('trivia','Which country has Dodoma as its capital?','["Tanzania", "Uzbekistan", "Belarus", "Czech Republic"]'::jsonb,'Tanzania'),
('trivia','What is the capital of Tanzania?','["Abu Dhabi", "Vienna", "Brazzaville", "Dodoma"]'::jsonb,'Dodoma'),
('trivia','Which of these countries uses currency code TZS?','["British Indian Ocean Territory", "Falkland Islands", "Tanzania", "Yemen"]'::jsonb,'Tanzania'),
('trivia','Which country has Bangkok as its capital?','["Vanuatu", "Belgium", "Denmark", "Thailand"]'::jsonb,'Thailand'),
('trivia','What is the capital of Thailand?','["Baku", "Kinshasa", "Bangkok", "London"]'::jsonb,'Bangkok'),
('trivia','Which of these countries uses currency code THB?','["Faroe Islands", "Thailand", "Zambia", "Brunei"]'::jsonb,'Thailand'),
('trivia','Which country has Dili as its capital?','["Belize", "Djibouti", "East Timor", "Venezuela"]'::jsonb,'East Timor'),
('trivia','What is the capital of East Timor?','["Avarua", "Dili", "Washington D.C.", "Nassau"]'::jsonb,'Dili'),
('trivia','Which country has Lomé as its capital?','["Dominica", "Togo", "Vietnam", "Benin"]'::jsonb,'Togo'),
('trivia','What is the capital of Togo?','["Lomé", "Montevideo", "Manama", "San José"]'::jsonb,'Lomé'),
('trivia','Which country has Fakaofo as its capital?','["Tokelau", "Wallis and Futuna", "Bermuda", "Dominican Republic"]'::jsonb,'Tokelau'),
('trivia','What is the capital of Tokelau?','["Tashkent", "Dhaka", "Yamoussoukro", "Fakaofo"]'::jsonb,'Fakaofo'),
('trivia','Which country has Nuku''alofa as its capital?','["Western Sahara", "Bhutan", "Ecuador", "Tonga"]'::jsonb,'Tonga'),
('trivia','What is the capital of Tonga?','["Bridgetown", "Zagreb", "Nuku''alofa", "Port Vila"]'::jsonb,'Nuku''alofa'),
('trivia','Which of these countries uses currency code TOP?','["French Guiana", "Tonga", "Algeria", "Cambodia"]'::jsonb,'Tonga'),
('trivia','Which country has Port of Spain as its capital?','["Bolivia", "Egypt", "Trinidad and Tobago", "Yemen"]'::jsonb,'Trinidad and Tobago'),
('trivia','What is the capital of Trinidad and Tobago?','["Havana", "Port of Spain", "Caracas", "Minsk"]'::jsonb,'Port of Spain'),
('trivia','Which of these countries uses currency code TTD?','["Trinidad and Tobago", "American Samoa", "Cameroon", "French Polynesia"]'::jsonb,'Trinidad and Tobago'),
('trivia','Which country has Tunis as its capital?','["El Salvador", "Tunisia", "Zambia", "Bosnia and Herzegovina"]'::jsonb,'Tunisia'),
('trivia','What is the capital of Tunisia?','["Tunis", "Hanoi", "Brussels", "Nicosia"]'::jsonb,'Tunis'),
('trivia','Which of these countries uses currency code TND?','["Angola", "Canada", "French Southern and Antarctic Lands", "Tunisia"]'::jsonb,'Tunisia'),
('trivia','Which country has Ankara as its capital?','["Turkey", "Zimbabwe", "Botswana", "Equatorial Guinea"]'::jsonb,'Turkey'),
('trivia','What is the capital of Turkey?','["Mata-Utu", "Belmopan", "Prague", "Ankara"]'::jsonb,'Ankara'),
('trivia','Which of these countries uses currency code TRY?','["Cape Verde", "Gabon", "Turkey", "Anguilla"]'::jsonb,'Turkey'),
('trivia','Which country has Ashgabat as its capital?','["Afghanistan", "Brazil", "Eritrea", "Turkmenistan"]'::jsonb,'Turkmenistan'),
('trivia','What is the capital of Turkmenistan?','["Porto-Novo", "Copenhagen", "Ashgabat", "El Aaiún"]'::jsonb,'Ashgabat'),
('trivia','Which of these countries uses currency code TMT?','["The Gambia", "Turkmenistan", "Antigua and Barbuda", "Cayman Islands"]'::jsonb,'Turkmenistan'),
('trivia','Which country has Funafuti as its capital?','["British Indian Ocean Territory", "Estonia", "Tuvalu", "Albania"]'::jsonb,'Tuvalu'),
('trivia','What is the capital of Tuvalu?','["Djibouti", "Funafuti", "Sana''a", "Hamilton"]'::jsonb,'Funafuti'),
('trivia','Which country has Kampala as its capital?','["Ethiopia", "Uganda", "Algeria", "Brunei"]'::jsonb,'Uganda'),
('trivia','What is the capital of Uganda?','["Kampala", "Lusaka", "Thimphu", "Roseau"]'::jsonb,'Kampala'),
('trivia','Which of these countries uses currency code UGX?','["Armenia", "Chad", "Germany", "Uganda"]'::jsonb,'Uganda'),
('trivia','Which country has Kiev as its capital?','["Ukraine", "American Samoa", "Bulgaria", "Falkland Islands"]'::jsonb,'Ukraine'),
('trivia','What is the capital of Ukraine?','["Harare", "Sucre", "Santo Domingo", "Kiev"]'::jsonb,'Kiev'),
('trivia','Which of these countries uses currency code UAH?','["Chile", "Ghana", "Ukraine", "Aruba"]'::jsonb,'Ukraine'),
('trivia','Which country has Abu Dhabi as its capital?','["Angola", "Burkina Faso", "Faroe Islands", "United Arab Emirates"]'::jsonb,'United Arab Emirates'),
('trivia','What is the capital of United Arab Emirates?','["Sarajevo", "Quito", "Abu Dhabi", "Kabul"]'::jsonb,'Abu Dhabi'),
('trivia','Which of these countries uses currency code AED?','["Gibraltar", "United Arab Emirates", "Australia", "China"]'::jsonb,'United Arab Emirates'),
('trivia','Which country has London as its capital?','["Burundi", "Fiji", "United Kingdom", "Anguilla"]'::jsonb,'United Kingdom'),
('trivia','What is the capital of United Kingdom?','["Cairo", "London", "Tirana", "Gaborone"]'::jsonb,'London'),
('trivia','Which country has Washington D.C. as its capital?','["Finland", "United States", "Antigua and Barbuda", "Cambodia"]'::jsonb,'United States'),
('trivia','What is the capital of United States?','["Washington D.C.", "Algiers", "Brasília", "San Salvador"]'::jsonb,'Washington D.C.'),
('trivia','Which country has Montevideo as its capital?','["Uruguay", "Argentina", "Cameroon", "France"]'::jsonb,'Uruguay'),
('trivia','What is the capital of Uruguay?','["Pago Pago", "Diego Garcia", "Malabo", "Montevideo"]'::jsonb,'Montevideo'),
('trivia','Which of these countries uses currency code UYI?','["Colombia", "Grenada", "Uruguay", "The Bahamas"]'::jsonb,'Uruguay'),
('trivia','Which country has Tashkent as its capital?','["Armenia", "Canada", "French Guiana", "Uzbekistan"]'::jsonb,'Uzbekistan'),
('trivia','What is the capital of Uzbekistan?','["Bandar Seri Begawan", "Asmara", "Tashkent", "Luanda"]'::jsonb,'Tashkent'),
('trivia','Which of these countries uses currency code UZS?','["Guadeloupe", "Uzbekistan", "Bahrain", "Comoros"]'::jsonb,'Uzbekistan'),
('trivia','Which country has Port Vila as its capital?','["Cape Verde", "French Polynesia", "Vanuatu", "Aruba"]'::jsonb,'Vanuatu'),
('trivia','What is the capital of Vanuatu?','["Tallinn", "Port Vila", "The Valley", "Sofia"]'::jsonb,'Port Vila'),
('trivia','Which of these countries uses currency code VUV?','["Vanuatu", "Bangladesh", "Republic of the Congo", "Guam"]'::jsonb,'Vanuatu'),
('trivia','Which country has Caracas as its capital?','["French Southern and Antarctic Lands", "Venezuela", "Australia", "Cayman Islands"]'::jsonb,'Venezuela'),
('trivia','What is the capital of Venezuela?','["Caracas", "Saint John''s", "Ouagadougou", "Addis Ababa"]'::jsonb,'Caracas'),
('trivia','Which of these countries uses currency code VEF?','["Barbados", "Democratic Republic of the Congo", "Guatemala", "Venezuela"]'::jsonb,'Venezuela'),
('trivia','Which country has Hanoi as its capital?','["Vietnam", "Austria", "Central African Republic", "Gabon"]'::jsonb,'Vietnam'),
('trivia','What is the capital of Vietnam?','["Buenos Aires", "Bujumbura", "Stanley", "Hanoi"]'::jsonb,'Hanoi'),
('trivia','Which of these countries uses currency code VND?','["Cook Islands", "Guernsey", "Vietnam", "Belarus"]'::jsonb,'Vietnam'),
('trivia','Which country has Mata-Utu as its capital?','["Azerbaijan", "Chad", "The Gambia", "Wallis and Futuna"]'::jsonb,'Wallis and Futuna'),
('trivia','What is the capital of Wallis and Futuna?','["Phnom Penh", "Tórshavn", "Mata-Utu", "Yerevan"]'::jsonb,'Mata-Utu'),
('trivia','Which country has El Aaiún as its capital?','["Chile", "Georgia", "Western Sahara", "The Bahamas"]'::jsonb,'Western Sahara'),
('trivia','What is the capital of Western Sahara?','["Suva", "El Aaiún", "Oranjestad", "Yaoundé"]'::jsonb,'El Aaiún'),
('trivia','Which country has Sana''a as its capital?','["Germany", "Yemen", "Bahrain", "China"]'::jsonb,'Yemen'),
('trivia','What is the capital of Yemen?','["Sana''a", "Canberra", "Ottawa", "Helsinki"]'::jsonb,'Sana''a'),
('trivia','Which of these countries uses currency code YER?','["Benin", "Croatia", "Guyana", "Yemen"]'::jsonb,'Yemen'),
('trivia','Which country has Lusaka as its capital?','["Zambia", "Bangladesh", "Christmas Island", "Ghana"]'::jsonb,'Zambia'),
('trivia','What is the capital of Zambia?','["Vienna", "Praia", "Paris", "Lusaka"]'::jsonb,'Lusaka'),
('trivia','Which of these countries uses currency code ZMK?','["Cuba", "Haiti", "Zambia", "Bermuda"]'::jsonb,'Zambia'),
('trivia','Which country has Harare as its capital?','["Barbados", "Cocos (Keeling) Islands", "Gibraltar", "Zimbabwe"]'::jsonb,'Zimbabwe'),
('trivia','What is the capital of Zimbabwe?','["George Town", "Cayenne", "Harare", "Baku"]'::jsonb,'Harare')
on conflict do nothing;

-- Emoji Decode: 80 visual culture rounds.
insert into private.game_question_bank(game_type,prompt,options,correct_answer) values
('emoji_decode','Decode the emoji: 🌧️☕📖','["Cozy rainy reading", "Late night study", "Puzzle challenge", "Forgot password"]'::jsonb,'Cozy rainy reading'),
('emoji_decode','Decode the emoji: ✈️🌍📸','["Football final", "Graduation day", "No Wi-Fi", "World travel"]'::jsonb,'World travel'),
('emoji_decode','Decode the emoji: 🎮🏆🔥','["Dog lover", "Running late", "Gaming champion", "Live concert"]'::jsonb,'Gaming champion'),
('emoji_decode','Decode the emoji: 🌙🎧💬','["Overslept", "Late night talk", "Night coding", "Cat in a box"]'::jsonb,'Late night talk'),
('emoji_decode','Decode the emoji: 🍕🎬🛋️','["Movie night", "Sunrise photography", "Rainy walk", "Aura moment"]'::jsonb,'Movie night'),
('emoji_decode','Decode the emoji: 🏖️🌊☀️','["Art studio", "City walk playlist", "Main character", "Beach day"]'::jsonb,'Beach day'),
('emoji_decode','Decode the emoji: 🚗🎵🛣️','["Shopping spree", "Rapid trivia", "Road trip", "Horror movie"]'::jsonb,'Road trip'),
('emoji_decode','Decode the emoji: 📚☕🌙','["Adventure trip", "Late night study", "Birthday party", "School day"]'::jsonb,'Late night study'),
('emoji_decode','Decode the emoji: ⚽🥅🏆','["Football final", "Gym session", "Breakfast time", "Favorite movie"]'::jsonb,'Football final'),
('emoji_decode','Decode the emoji: 🎤🎶✨','["Fast food", "Spicy food", "Summer vibes", "Live concert"]'::jsonb,'Live concert'),
('emoji_decode','Decode the emoji: 💻☕🌃','["Game night", "Winter vibes", "Night coding", "Space trip"]'::jsonb,'Night coding'),
('emoji_decode','Decode the emoji: 📷🌅🏔️','["Halloween night", "Sunrise photography", "Camping night", "Dead phone battery"]'::jsonb,'Sunrise photography'),
('emoji_decode','Decode the emoji: 🎨🖌️🖼️','["Art studio", "Puzzle challenge", "Forgot password", "New year"]'::jsonb,'Art studio'),
('emoji_decode','Decode the emoji: 🍿👻🎬','["Graduation day", "No Wi-Fi", "Startup idea", "Horror movie"]'::jsonb,'Horror movie'),
('emoji_decode','Decode the emoji: 🎁🎂🎉','["Running late", "Shower concert", "Birthday party", "Dog lover"]'::jsonb,'Birthday party'),
('emoji_decode','Decode the emoji: 🏋️💪🎧','["Bike ride", "Gym session", "Cat in a box", "Overslept"]'::jsonb,'Gym session'),
('emoji_decode','Decode the emoji: 🍔🍟🥤','["Fast food", "Rainy walk", "Aura moment", "Sweet tooth"]'::jsonb,'Fast food'),
('emoji_decode','Decode the emoji: 🚀🌌🪐','["City walk playlist", "Main character", "Work session", "Space trip"]'::jsonb,'Space trip'),
('emoji_decode','Decode the emoji: 🌲⛺🔥','["Rapid trivia", "Learning something new", "Camping night", "Shopping spree"]'::jsonb,'Camping night'),
('emoji_decode','Decode the emoji: 🧩🧠⏱️','["Impulse purchase", "Puzzle challenge", "School day", "Adventure trip"]'::jsonb,'Puzzle challenge'),
('emoji_decode','Decode the emoji: 🎓📜🎉','["Graduation day", "Breakfast time", "Favorite movie", "Vacation mode"]'::jsonb,'Graduation day'),
('emoji_decode','Decode the emoji: 🐶🦴❤️','["Spicy food", "Summer vibes", "Mystery solving", "Dog lover"]'::jsonb,'Dog lover'),
('emoji_decode','Decode the emoji: 🐱📦😹','["Winter vibes", "Comedy show", "Cat in a box", "Game night"]'::jsonb,'Cat in a box'),
('emoji_decode','Decode the emoji: 🌧️☂️👟','["Band practice", "Rainy walk", "Dead phone battery", "Halloween night"]'::jsonb,'Rainy walk'),
('emoji_decode','Decode the emoji: 🎧🚶🌆','["City walk playlist", "Forgot password", "New year", "Stargazing"]'::jsonb,'City walk playlist'),
('emoji_decode','Decode the emoji: 🛍️👟🧢','["No Wi-Fi", "Startup idea", "Basketball game", "Shopping spree"]'::jsonb,'Shopping spree'),
('emoji_decode','Decode the emoji: 🚌🎒🏫','["Shower concert", "Race day", "School day", "Running late"]'::jsonb,'School day'),
('emoji_decode','Decode the emoji: 🍳🥞☕','["Noodle night", "Breakfast time", "Overslept", "Bike ride"]'::jsonb,'Breakfast time'),
('emoji_decode','Decode the emoji: 🌮🌶️🔥','["Spicy food", "Aura moment", "Sweet tooth", "Freezing cold"]'::jsonb,'Spicy food'),
('emoji_decode','Decode the emoji: 🎲👥😂','["Main character", "Work session", "Too hot", "Game night"]'::jsonb,'Game night'),
('emoji_decode','Decode the emoji: 📱🔋0️⃣','["Learning something new", "Delivery day", "Dead phone battery", "Rapid trivia"]'::jsonb,'Dead phone battery'),
('emoji_decode','Decode the emoji: 🔐🤔💻','["Sweet message", "Forgot password", "Adventure trip", "Impulse purchase"]'::jsonb,'Forgot password'),
('emoji_decode','Decode the emoji: 📶❌😤','["No Wi-Fi", "Favorite movie", "Vacation mode", "Perfect selfie"]'::jsonb,'No Wi-Fi'),
('emoji_decode','Decode the emoji: 🕒🏃🚪','["Summer vibes", "Mystery solving", "Cleaning day", "Running late"]'::jsonb,'Running late'),
('emoji_decode','Decode the emoji: 🛌⏰😴','["Comedy show", "Plant care", "Overslept", "Winter vibes"]'::jsonb,'Overslept'),
('emoji_decode','Decode the emoji: 💬😂⚡','["Perfect aim", "Aura moment", "Halloween night", "Band practice"]'::jsonb,'Aura moment'),
('emoji_decode','Decode the emoji: 👑⚡🏆','["Main character", "New year", "Stargazing", "Deep thoughts"]'::jsonb,'Main character'),
('emoji_decode','Decode the emoji: 🧠❓⚡','["Startup idea", "Basketball game", "Slow morning", "Rapid trivia"]'::jsonb,'Rapid trivia'),
('emoji_decode','Decode the emoji: 🗺️🧭🎒','["Race day", "Fell asleep watching", "Adventure trip", "Shower concert"]'::jsonb,'Adventure trip'),
('emoji_decode','Decode the emoji: 🎬🍿❤️','["Backpacking", "Favorite movie", "Bike ride", "Noodle night"]'::jsonb,'Favorite movie'),
('emoji_decode','Decode the emoji: ☀️🕶️🍹','["Summer vibes", "Sweet tooth", "Freezing cold", "Fixing a bug"]'::jsonb,'Summer vibes'),
('emoji_decode','Decode the emoji: ❄️🧣☕','["Work session", "Too hot", "Cooking dinner", "Winter vibes"]'::jsonb,'Winter vibes'),
('emoji_decode','Decode the emoji: 🎃👻🍬','["Delivery day", "Song on repeat", "Halloween night", "Learning something new"]'::jsonb,'Halloween night'),
('emoji_decode','Decode the emoji: 🎆🎉🕛','["Big idea", "New year", "Impulse purchase", "Sweet message"]'::jsonb,'New year'),
('emoji_decode','Decode the emoji: 💡📝🚀','["Startup idea", "Vacation mode", "Perfect selfie", "Task complete"]'::jsonb,'Startup idea'),
('emoji_decode','Decode the emoji: 🎵🚿🎤','["Mystery solving", "Cleaning day", "First place", "Shower concert"]'::jsonb,'Shower concert'),
('emoji_decode','Decode the emoji: 🚲🌳☀️','["Plant care", "Retro gaming", "Bike ride", "Comedy show"]'::jsonb,'Bike ride'),
('emoji_decode','Decode the emoji: 🧁🎂🍪','["Night ride", "Sweet tooth", "Band practice", "Perfect aim"]'::jsonb,'Sweet tooth'),
('emoji_decode','Decode the emoji: ☕💻📋','["Work session", "Stargazing", "Deep thoughts", "Dance floor"]'::jsonb,'Work session'),
('emoji_decode','Decode the emoji: 📖🧠✨','["Basketball game", "Slow morning", "Cozy rainy reading", "Learning something new"]'::jsonb,'Learning something new'),
('emoji_decode','Decode the emoji: 💸🛍️😬','["Fell asleep watching", "World travel", "Impulse purchase", "Race day"]'::jsonb,'Impulse purchase'),
('emoji_decode','Decode the emoji: 🧳✈️😎','["Gaming champion", "Vacation mode", "Noodle night", "Backpacking"]'::jsonb,'Vacation mode'),
('emoji_decode','Decode the emoji: 🔎🕵️‍♂️🧩','["Mystery solving", "Freezing cold", "Fixing a bug", "Late night talk"]'::jsonb,'Mystery solving'),
('emoji_decode','Decode the emoji: 🎭😂👏','["Too hot", "Cooking dinner", "Movie night", "Comedy show"]'::jsonb,'Comedy show'),
('emoji_decode','Decode the emoji: 🎸🥁🎤','["Song on repeat", "Beach day", "Band practice", "Delivery day"]'::jsonb,'Band practice'),
('emoji_decode','Decode the emoji: 🌌🔭✨','["Road trip", "Stargazing", "Sweet message", "Big idea"]'::jsonb,'Stargazing'),
('emoji_decode','Decode the emoji: 🏀⛹️🏆','["Basketball game", "Perfect selfie", "Task complete", "Late night study"]'::jsonb,'Basketball game'),
('emoji_decode','Decode the emoji: 🏎️🏁🔥','["Cleaning day", "First place", "Football final", "Race day"]'::jsonb,'Race day'),
('emoji_decode','Decode the emoji: 🍜🥢😋','["Retro gaming", "Live concert", "Noodle night", "Plant care"]'::jsonb,'Noodle night'),
('emoji_decode','Decode the emoji: 🥶🧊❄️','["Night coding", "Freezing cold", "Perfect aim", "Night ride"]'::jsonb,'Freezing cold'),
('emoji_decode','Decode the emoji: 🔥☀️🥵','["Too hot", "Deep thoughts", "Dance floor", "Sunrise photography"]'::jsonb,'Too hot'),
('emoji_decode','Decode the emoji: 📦🚚🏠','["Slow morning", "Cozy rainy reading", "Art studio", "Delivery day"]'::jsonb,'Delivery day'),
('emoji_decode','Decode the emoji: 💌❤️😊','["World travel", "Horror movie", "Sweet message", "Fell asleep watching"]'::jsonb,'Sweet message'),
('emoji_decode','Decode the emoji: 📸🤳✨','["Birthday party", "Perfect selfie", "Backpacking", "Gaming champion"]'::jsonb,'Perfect selfie'),
('emoji_decode','Decode the emoji: 🧹🧼🏠','["Cleaning day", "Fixing a bug", "Late night talk", "Gym session"]'::jsonb,'Cleaning day'),
('emoji_decode','Decode the emoji: 🪴🌱☀️','["Cooking dinner", "Movie night", "Fast food", "Plant care"]'::jsonb,'Plant care'),
('emoji_decode','Decode the emoji: 🎯🏹🏆','["Beach day", "Space trip", "Perfect aim", "Song on repeat"]'::jsonb,'Perfect aim'),
('emoji_decode','Decode the emoji: 🧠💭🌙','["Camping night", "Deep thoughts", "Big idea", "Road trip"]'::jsonb,'Deep thoughts'),
('emoji_decode','Decode the emoji: 😶‍🌫️☕🌅','["Slow morning", "Task complete", "Late night study", "Puzzle challenge"]'::jsonb,'Slow morning'),
('emoji_decode','Decode the emoji: 🍿📺😴','["First place", "Football final", "Graduation day", "Fell asleep watching"]'::jsonb,'Fell asleep watching'),
('emoji_decode','Decode the emoji: 🎒🗺️🚶','["Live concert", "Dog lover", "Backpacking", "Retro gaming"]'::jsonb,'Backpacking'),
('emoji_decode','Decode the emoji: 🛠️💻🐛','["Cat in a box", "Fixing a bug", "Night ride", "Night coding"]'::jsonb,'Fixing a bug'),
('emoji_decode','Decode the emoji: 🧑‍🍳🍝🔥','["Cooking dinner", "Dance floor", "Sunrise photography", "Rainy walk"]'::jsonb,'Cooking dinner'),
('emoji_decode','Decode the emoji: 🎧🎶🔁','["Cozy rainy reading", "Art studio", "City walk playlist", "Song on repeat"]'::jsonb,'Song on repeat'),
('emoji_decode','Decode the emoji: 💡⚡🧠','["Horror movie", "Shopping spree", "Big idea", "World travel"]'::jsonb,'Big idea'),
('emoji_decode','Decode the emoji: 📝✅🎯','["School day", "Task complete", "Gaming champion", "Birthday party"]'::jsonb,'Task complete'),
('emoji_decode','Decode the emoji: 🏆🥇⚡','["First place", "Late night talk", "Gym session", "Breakfast time"]'::jsonb,'First place'),
('emoji_decode','Decode the emoji: 🕹️👾🎮','["Movie night", "Fast food", "Spicy food", "Retro gaming"]'::jsonb,'Retro gaming'),
('emoji_decode','Decode the emoji: 🌃🚕🎵','["Space trip", "Game night", "Night ride", "Beach day"]'::jsonb,'Night ride'),
('emoji_decode','Decode the emoji: 🪩💃🎶','["Dead phone battery", "Dance floor", "Road trip", "Camping night"]'::jsonb,'Dance floor')
on conflict do nothing;


-- Server-authoritative round creation remains private. Most Likely To derives its options from room members.
create or replace function private.make_game_round(p_session uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_session public.game_sessions%rowtype;
  v_room public.rooms%rowtype;
  v_cfg public.room_config%rowtype;
  v_q private.game_question_bank%rowtype;
  v_round uuid;
  v_options jsonb;
begin
  select * into v_session from public.game_sessions where id=p_session for update;
  if not found or v_session.status<>'active' then raise exception 'Game session unavailable.'; end if;
  select * into v_room from public.rooms where id=v_session.room_id;
  select * into v_cfg from public.room_config where id=1;

  select * into v_q from private.game_question_bank q
  where q.game_type=v_session.game_type and q.active=true
    and not exists(select 1 from public.game_rounds gr where gr.session_id=v_session.id and gr.prompt=q.prompt)
  order by random() limit 1;
  if not found then raise exception 'No questions configured for this game.'; end if;

  if v_session.game_type='most_likely' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'value',p.user_id::text,
      'label',coalesce(p.display_name,p.username,'VYBE user'),
      'username',p.username
    ) order by coalesce(p.display_name,p.username)), '[]'::jsonb)
      into v_options
    from public.room_members rm join public.profiles p on p.user_id=rm.user_id
    where rm.room_id=v_session.room_id and rm.status='active';
  else
    v_options:=v_q.options;
  end if;

  insert into public.game_rounds(session_id,round_no,prompt,options,ends_at)
  values(v_session.id,v_session.current_round,v_q.prompt,v_options,now()+make_interval(secs=>v_cfg.round_seconds))
  returning id into v_round;

  insert into private.game_answer_keys(round_id,correct_answer) values(v_round,v_q.correct_answer);
  insert into public.room_events(room_id,event_type,actor_id,payload)
  values(v_session.room_id,'round_started',null,jsonb_build_object('session_id',v_session.id,'round_id',v_round,'round_no',v_session.current_round));
  return v_round;
end;
$$;
revoke execute on function private.make_game_round(uuid) from public,anon,authenticated;

create or replace function public.start_room_game(p_room uuid,p_game_type text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_room public.rooms%rowtype; v_cfg public.room_config%rowtype; v_count integer; v_session uuid; v_round uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_game_type not in('puzzle','trivia','most_likely','would_you_rather','emoji_decode','riddle','word_scramble','spot_lie') then raise exception 'Unknown game.'; end if;
  select * into v_room from public.rooms where id=p_room for update;
  if not found or v_room.status='ended' or v_room.expires_at<=now() then raise exception 'Room unavailable.'; end if;
  if v_room.created_by<>v_user then raise exception 'Only the host can start a game.'; end if;
  if v_room.current_session_id is not null then raise exception 'A game is already running.'; end if;
  select * into v_cfg from public.room_config where id=1;
  select count(*) into v_count from public.room_members where room_id=p_room and status='active';
  if v_count<v_cfg.min_players then raise exception 'At least % active players are required.',v_cfg.min_players; end if;
  insert into public.game_sessions(room_id,game_type,max_rounds,started_by) values(p_room,p_game_type,v_cfg.rounds_per_game,v_user) returning id into v_session;
  update public.rooms set status='playing',current_session_id=v_session,updated_at=now() where id=p_room;
  v_round:=private.make_game_round(v_session);
  insert into public.room_events(room_id,event_type,actor_id,payload) values(p_room,'game_started',v_user,jsonb_build_object('session_id',v_session,'game_type',p_game_type));
  return jsonb_build_object('ok',true,'session_id',v_session,'round_id',v_round);
end;
$$;
revoke execute on function public.start_room_game(uuid,text) from public,anon;
grant execute on function public.start_room_game(uuid,text) to authenticated;

create or replace function public.submit_game_answer(p_session uuid,p_round uuid,p_answer text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_session public.game_sessions%rowtype; v_round public.game_rounds%rowtype; v_key text; v_score integer:=0; v_correct boolean; v_elapsed numeric; v_option_ok boolean;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_session from public.game_sessions where id=p_session;
  if not found or v_session.status<>'active' or not public.room_is_member(v_session.room_id,false) then raise exception 'Game unavailable.'; end if;
  select * into v_round from public.game_rounds where id=p_round and session_id=p_session for update;
  if not found or v_round.status<>'active' then raise exception 'Round is closed.'; end if;
  if now()>v_round.ends_at then raise exception 'Time is up.'; end if;
  if exists(select 1 from public.game_submissions where round_id=p_round and user_id=v_user) then
    return jsonb_build_object('ok',true,'already_submitted',true);
  end if;
  select exists(
    select 1 from jsonb_array_elements(v_round.options) as elem(value)
    where (case when jsonb_typeof(elem.value)='object' then elem.value->>'value' else trim(both '"' from elem.value::text) end)=p_answer
  ) into v_option_ok;
  if not v_option_ok then raise exception 'Invalid answer.'; end if;

  select correct_answer into v_key from private.game_answer_keys where round_id=p_round;
  if v_session.game_type='most_likely' then
    if p_answer=v_user::text then raise exception 'Pick someone else.'; end if;
    v_correct:=null; v_score:=20;
  elsif v_session.game_type='would_you_rather' then
    v_correct:=null; v_score:=0; -- scored once the majority is known at round close
  else
    v_correct:=(p_answer=v_key);
    v_elapsed:=greatest(extract(epoch from (now()-v_round.started_at)),0);
    v_score:=case when v_correct then 100+greatest(0,round(50-(v_elapsed*2)))::integer else 0 end;
  end if;
  insert into public.game_submissions(round_id,session_id,user_id,answer,score,is_correct) values(p_round,p_session,v_user,p_answer,v_score,v_correct);
  return jsonb_build_object('ok',true,'already_submitted',false,'score',v_score,'correct',v_correct);
end;
$$;
revoke execute on function public.submit_game_answer(uuid,uuid,text) from public,anon;
grant execute on function public.submit_game_answer(uuid,uuid,text) to authenticated;

create or replace function public.advance_room_game(p_session uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid(); v_session public.game_sessions%rowtype; v_round public.game_rounds%rowtype; v_active integer; v_submitted integer; v_next uuid; v_cfg public.room_config%rowtype; v_winner uuid; v_top integer; v_rank integer:=0; r record;
  v_majority text; v_max integer; v_ties integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_session from public.game_sessions where id=p_session for update;
  if not found or v_session.status<>'active' or not public.room_is_member(v_session.room_id,false) then raise exception 'Game unavailable.'; end if;
  select * into v_round from public.game_rounds where session_id=p_session and status='active' order by round_no desc limit 1 for update;
  if not found then raise exception 'No active round.'; end if;
  select count(*) into v_active from public.room_members where room_id=v_session.room_id and status='active';
  select count(*) into v_submitted from public.game_submissions where round_id=v_round.id;
  if now()<v_round.ends_at and v_submitted<v_active then
    return jsonb_build_object('ok',true,'waiting',true,'submitted',v_submitted,'active_players',v_active,'ends_at',v_round.ends_at);
  end if;

  -- Would You Rather rewards predicting the room majority. A tied room gives everyone 50.
  if v_session.game_type='would_you_rather' then
    select max(c) into v_max from (select answer,count(*)::integer c from public.game_submissions where round_id=v_round.id group by answer) x;
    select count(*) into v_ties from (select answer,count(*)::integer c from public.game_submissions where round_id=v_round.id group by answer) x where c=v_max;
    select answer into v_majority from (select answer,count(*)::integer c from public.game_submissions where round_id=v_round.id group by answer order by c desc,answer limit 1) x;
    if coalesce(v_ties,0)>1 then
      update public.game_submissions set score=50 where round_id=v_round.id;
    else
      update public.game_submissions set score=case when answer=v_majority then 100 else 20 end where round_id=v_round.id;
    end if;
  end if;

  update public.game_rounds set status='finished',finished_at=now() where id=v_round.id;
  insert into public.room_events(room_id,event_type,actor_id,payload) values(v_session.room_id,'round_finished',v_user,jsonb_build_object('session_id',p_session,'round_no',v_round.round_no));

  if v_session.current_round < v_session.max_rounds then
    update public.game_sessions set current_round=current_round+1 where id=p_session returning * into v_session;
    v_next:=private.make_game_round(p_session);
    return jsonb_build_object('ok',true,'finished',false,'next_round_id',v_next,'round_no',v_session.current_round);
  end if;

  select * into v_cfg from public.room_config where id=1;
  for r in
    select rm.user_id,
      case when v_session.game_type='most_likely' then
        (select count(*)::integer*100 from public.game_submissions vote where vote.session_id=p_session and vote.answer=rm.user_id::text)
      else coalesce(sum(s.score),0)::integer end as total_score,
      min(s.submitted_at) first_submit
    from public.room_members rm left join public.game_submissions s on s.session_id=p_session and s.user_id=rm.user_id
    where rm.room_id=v_session.room_id and rm.status='active'
    group by rm.user_id
    order by total_score desc, first_submit asc nulls last, rm.user_id
  loop
    v_rank:=v_rank+1;
    if v_rank=1 then v_winner:=r.user_id; v_top:=r.total_score; end if;
    insert into public.game_results(session_id,room_id,user_id,total_score,placement,is_winner,is_mvp)
    values(p_session,v_session.room_id,r.user_id,r.total_score,v_rank,(v_rank=1 and r.total_score>0),(v_rank=1 and r.total_score>0))
    on conflict(session_id,user_id) do nothing;
    update public.profiles set vibe_xp=vibe_xp+case when v_rank=1 then v_cfg.winner_xp else v_cfg.participation_xp end,
      room_wins=room_wins+case when v_rank=1 and r.total_score>0 then 1 else 0 end where user_id=r.user_id;
  end loop;

  if v_winner is not null and coalesce(v_top,0)>0 then
    perform public.award_verified_aura(v_winner,'game',p_session,v_cfg.winner_aura,'Room game winner');
    perform public.award_verified_aura(v_winner,'room_mvp',p_session,v_cfg.mvp_aura,'Room MVP');
  end if;
  update public.game_sessions set status='finished',finished_at=now() where id=p_session;
  update public.rooms set status='lobby',current_session_id=null,updated_at=now() where id=v_session.room_id;
  insert into public.room_events(room_id,event_type,actor_id,payload) values(v_session.room_id,'game_finished',null,jsonb_build_object('session_id',p_session,'winner_id',v_winner,'top_score',v_top));
  return jsonb_build_object('ok',true,'finished',true,'winner_id',v_winner,'winner_score',v_top,'winner_aura',v_cfg.winner_aura,'mvp_aura',v_cfg.mvp_aura);
end;
$$;
revoke execute on function public.advance_room_game(uuid) from public,anon;
grant execute on function public.advance_room_game(uuid) to authenticated;

-- Update HQ write validation for all eight games.
create or replace function public.admin_upsert_game_question(p_id bigint,p_game text,p_prompt text,p_options jsonb,p_correct text,p_active boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id bigint; v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if p_game not in('puzzle','trivia','most_likely','would_you_rather','emoji_decode','riddle','word_scramble','spot_lie') then raise exception 'Unknown game'; end if;
  if p_id is not null then select to_jsonb(q) into v_before from private.game_question_bank q where q.id=p_id; end if;
  if p_id is null then insert into private.game_question_bank(game_type,prompt,options,correct_answer,active) values(p_game,trim(p_prompt),coalesce(p_options,'[]'::jsonb),nullif(trim(p_correct),''),p_active) returning id into v_id;
  else update private.game_question_bank set game_type=p_game,prompt=trim(p_prompt),options=coalesce(p_options,'[]'::jsonb),correct_answer=nullif(trim(p_correct),''),active=p_active where id=p_id returning id into v_id; end if;
  select to_jsonb(q) into v_after from private.game_question_bank q where q.id=v_id;
  perform private.audit_admin('game_question_upsert','game_question',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_game_question(bigint,text,text,jsonb,text,boolean,text) from public,anon;
grant execute on function public.admin_upsert_game_question(bigint,text,text,jsonb,text,boolean,text) to authenticated;

-- A safe aggregate for HQ/diagnostics; never exposes correct answers.
create or replace function public.get_game_bank_stats()
returns table(game_type text,active_questions bigint)
language sql stable security definer set search_path='' as $$
  select q.game_type::text,count(*)::bigint from private.game_question_bank q where q.active=true group by q.game_type order by q.game_type;
$$;
revoke execute on function public.get_game_bank_stats() from public,anon;
grant execute on function public.get_game_bank_stats() to authenticated;

-- Migration assertion: VYBE must leave this migration with >10k active prompts.
do $$
declare v_total bigint;
begin
  select count(*) into v_total from private.game_question_bank where active=true;
  if v_total < 10000 then raise exception 'VYBE game bank seed incomplete: only % active prompts',v_total; end if;
end $$;

commit;
