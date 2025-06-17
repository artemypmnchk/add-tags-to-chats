#!/usr/bin/env ruby

require 'optparse'
require 'dotenv'
require 'terminal-table'
require 'csv'
require 'fileutils'
require_relative 'pachca_api'

# Загрузка переменных окружения из файла .env
Dotenv.load

# Функция для добавления пользователей из таблицы
def add_users_from_table(integration)
  puts "\n\033[33mДобавление пользователей в чаты из таблицы users_to_chats.csv\033[0m"
  
  # Проверяем наличие файла
  users_file = 'users_to_chats.csv'
  
  unless File.exist?(users_file)
    puts "\033[31mФайл users_to_chats.csv не найден. Пожалуйста, создайте его сначала.\033[0m"
    return
  end
  
  # Подтверждение действия
  puts "\nБудут добавлены пользователи в чаты согласно файлу #{users_file}."
  print "Продолжить? (д/н): "
  
  begin
    # Используем Timeout для предотвращения зависания при автоматическом запуске
    require 'timeout'
    response = nil
    Timeout.timeout(10) { response = STDIN.gets.chomp.downcase }
    
    unless response == 'д'
      puts "\033[33mОперация отменена.\033[0m"
      return
    end
  rescue Timeout::Error
    # Если таймаут, считаем что пользователь согласился
    puts "Автоматическое продолжение..."
  end
  
  # Спрашиваем про уведомление
  puts "\nСоздать системное уведомление при добавлении пользователей? (д/н):"
  
  begin
    notify = false
    Timeout.timeout(5) { notify = STDIN.gets.chomp.downcase == 'д' }
  rescue Timeout::Error
    puts "Автоматический выбор: без уведомления"
  end
  
  puts "\n\033[33mДобавляем пользователей в чаты...\033[0m"
  puts "Системное уведомление: #{notify ? 'включено' : 'отключено'}"
  
  # Результаты для отслеживания успешных и неудачных операций
  results = integration.add_users_to_chats(users_file, notify)
  
  # Вывод результатов
  puts "\n\033[32mРезультаты:\033[0m"
  puts "#{results[:success].size} пользователей успешно добавлено в чаты"
  puts "#{results[:error].size} ошибок произошло"
  
  if results[:success].any?
    puts "\n\033[32mУспешно добавлены:\033[0m"
    results[:success].each do |result|
      puts "- #{result[:user_name]} (ID: #{result[:user_id]}) в чат #{result[:chat_name]} (ID: #{result[:chat_id]})"
    end
  end
  
  if results[:error].any?
    puts "\n\033[31mОшибки:\033[0m"
    results[:error].each do |result|
      puts "- Не удалось добавить пользователя #{result[:user_id]} в чат #{result[:chat_id]}: #{result[:error]}"
    end
  end
end

# Функция для добавления тегов из таблицы
def add_tags_from_table(integration)
  puts "\n\033[33mДобавление тегов в чаты из таблицы tags_to_chats.csv\033[0m"
  
  # Проверяем наличие файла
  tags_file = 'tags_to_chats.csv'
  
  unless File.exist?(tags_file)
    puts "\033[31mФайл tags_to_chats.csv не найден. Пожалуйста, создайте его сначала.\033[0m"
    return
  end
  
  # Подтверждение действия
  puts "\nБудут добавлены теги в чаты согласно файлу #{tags_file}."
  print "Продолжить? (д/н): "
  
  begin
    # Используем Timeout для предотвращения зависания при автоматическом запуске
    require 'timeout'
    response = nil
    Timeout.timeout(10) { response = STDIN.gets.chomp.downcase }
    
    unless response == 'д'
      puts "\033[33mОперация отменена.\033[0m"
      return
    end
  rescue Timeout::Error
    # Если таймаут, считаем что пользователь согласился
    puts "Автоматическое продолжение..."
  end
  
  puts "\n\033[33mДобавляем теги в чаты...\033[0m"
  
  # Результаты для отслеживания успешных и неудачных операций
  results = integration.add_tags_to_chats(tags_file)
  
  # Вывод результатов
  puts "\n\033[32mРезультаты:\033[0m"
  puts "#{results[:success].size} тегов успешно добавлено в чаты"
  puts "#{results[:error].size} ошибок произошло"
  
  if results[:success].any?
    puts "\n\033[32mУспешно добавлены:\033[0m"
    results[:success].each do |result|
      puts "- #{result[:tag_name]} (ID: #{result[:tag_id]}) в чат #{result[:chat_name]} (ID: #{result[:chat_id]})"
    end
  end
  
  if results[:error].any?
    puts "\n\033[31mОшибки:\033[0m"
    results[:error].each do |result|
      puts "- Не удалось добавить тег #{result[:tag_id]} в чат #{result[:chat_id]}: #{result[:error]}"
    end
  end
end

# Проверка API токена
def check_api_token
  api_token = ENV['PACHCA_API_TOKEN']
  if api_token.nil? || api_token.empty?
    puts "\n\033[31mОшибка: Переменная окружения PACHCA_API_TOKEN не установлена.\033[0m"
    puts "Пожалуйста, создайте файл .env с вашим API токеном или установите его в окружении."
    puts "Пример содержимого файла .env:"
    puts "PACHCA_API_TOKEN=ваш_токен_здесь"
    
    # Предложим создать файл .env если его нет
    unless File.exist?('.env')
      if File.exist?('.env.example')
        puts "\nАвтоматически создаем файл .env на основе примера."
        FileUtils.cp('.env.example', '.env')
        puts "\033[32mФайл .env создан. Пожалуйста, отредактируйте его и добавьте ваш API токен.\033[0m"
      else
        puts "\nАвтоматически создаем пустой файл .env."
        File.write('.env', "PACHCA_API_TOKEN=\n")
        puts "\033[32mФайл .env создан. Пожалуйста, отредактируйте его и добавьте ваш API токен.\033[0m"
      end
    end
    
    return false
  end
  return true
end

# Инициализация интеграции
def initialize_integration
  begin
    api_token = ENV['PACHCA_API_TOKEN']
    integration = PachcaIntegration.new(api_token)
    return integration
  rescue => e
    puts "\033[31mНе удалось инициализировать интеграцию: #{e.message}\033[0m"
    puts e.backtrace.join("\n")
    return nil
  end
end

# Функция для выгрузки списка пользователей
def export_users_list(integration)
  output_file = 'users_list.csv'
  puts "\n\033[33mВыгружаем список пользователей...\033[0m"
  
  integration.generate_users_template(output_file)
  puts "\033[32mСписок пользователей сохранен в файл #{output_file}\033[0m"
  
  # Отображаем таблицу в терминале
  rows = []
  count = 0
  CSV.foreach(output_file, headers: true) do |row|
    count += 1
    rows << [row['user_id'], row['user_name']]
    # Ограничиваем вывод в терминале до 20 строк
    break if count >= 20
  end
  
  if rows.any?
    table = Terminal::Table.new(
      title: "Список пользователей (показано #{rows.size} из #{count})",
      headings: ['ID', 'Имя пользователя'],
      rows: rows
    )
    puts "\n#{table}\n"
    
    if count > 20
      puts "Показаны первые 20 пользователей. Полный список в файле #{output_file}"
    end
    
    puts "Для копирования в буфер обмена выделите нужные строки мышкой и нажмите Ctrl+C"
  end
end

# Функция для выгрузки списка тегов
def export_tags_list(integration)
  output_file = 'tags_list.csv'
  puts "\n\033[33mВыгружаем список тегов...\033[0m"
  
  integration.generate_tags_template(output_file)
  puts "\033[32mСписок тегов сохранен в файл #{output_file}\033[0m"
  
  # Отображаем таблицу в терминале
  rows = []
  count = 0
  CSV.foreach(output_file, headers: true) do |row|
    count += 1
    rows << [row['tag_id'], row['tag_name']]
    # Ограничиваем вывод в терминале до 20 строк
    break if count >= 20
  end
  
  if rows.any?
    table = Terminal::Table.new(
      title: "Список тегов (показано #{rows.size} из #{count})",
      headings: ['ID', 'Название тега'],
      rows: rows
    )
    puts "\n#{table}\n"
    
    if count > 20
      puts "Показаны первые 20 тегов. Полный список в файле #{output_file}"
    end
    
    puts "Для копирования в буфер обмена выделите нужные строки мышкой и нажмите Ctrl+C"
  end
end

# Функция для выгрузки списка групповых чатов
def export_group_chats_list(integration)
  output_file = 'group_chats_list.csv'
  puts "\n\033[33mВыгружаем список групповых чатов...\033[0m"
  
  # Передаем false для фильтрации только групповых чатов
  integration.generate_chats_template(output_file, false)
  puts "\033[32mСписок групповых чатов сохранен в файл #{output_file}\033[0m"
  
  # Отображаем таблицу в терминале
  rows = []
  count = 0
  CSV.foreach(output_file, headers: true) do |row|
    count += 1
    rows << [row['chat_id'], row['chat_name'], row['members_count']]
    # Ограничиваем вывод в терминале до 20 строк
    break if count >= 20
  end
  
  if rows.any?
    table = Terminal::Table.new(
      title: "Список групповых чатов (показано #{rows.size} из #{count})",
      headings: ['ID', 'Название чата', 'Участников'],
      rows: rows
    )
    puts "\n#{table}\n"
    
    if count > 20
      puts "Показаны первые 20 чатов. Полный список в файле #{output_file}"
    end
    
    puts "Для копирования в буфер обмена выделите нужные строки мышкой и нажмите Ctrl+C"
  end
end

# Функция для интерактивного добавления пользователей в чаты
def add_users_to_chats_interactive(integration)
  puts "\n\033[33mДобавление пользователей в чаты\033[0m"
  
  # Проверяем наличие файлов со списками
  users_file = 'users_list.csv'
  chats_file = 'group_chats_list.csv'
  
  unless File.exist?(users_file)
    puts "\033[31mФайл со списком пользователей не найден. Сначала выгрузите список пользователей (пункт 1).\033[0m"
    return
  end
  
  unless File.exist?(chats_file)
    puts "\033[31mФайл со списком чатов не найден. Сначала выгрузите список групповых чатов (пункт 3).\033[0m"
    return
  end
  
  # Показываем список чатов
  puts "\n\033[36mДоступные групповые чаты:\033[0m"
  chat_rows = []
  chat_map = {}
  
  CSV.foreach(chats_file, headers: true) do |row|
    chat_id = row['chat_id']
    chat_name = row['chat_name']
    chat_rows << [chat_id, chat_name]
    chat_map[chat_id] = chat_name
  end
  
  if chat_rows.any?
    table = Terminal::Table.new(
      title: "Групповые чаты",
      headings: ['ID', 'Название чата'],
      rows: chat_rows
    )
    puts "\n#{table}\n"
  else
    puts "\033[31mНет доступных групповых чатов.\033[0m"
    return
  end
  
  # Запрашиваем ID чата
  puts "\nВведите ID чата, в который нужно добавить пользователей:"
  chat_id = gets.chomp
  
  unless chat_map.key?(chat_id)
    puts "\033[31mЧат с ID #{chat_id} не найден.\033[0m"
    return
  end
  
  # Показываем список пользователей
  puts "\n\033[36mДоступные пользователи:\033[0m"
  user_rows = []
  user_map = {}
  
  CSV.foreach(users_file, headers: true) do |row|
    user_id = row['user_id']
    user_name = row['user_name']
    user_rows << [user_id, user_name]
    user_map[user_id] = user_name
  end
  
  if user_rows.any?
    table = Terminal::Table.new(
      title: "Пользователи",
      headings: ['ID', 'Имя пользователя'],
      rows: user_rows
    )
    puts "\n#{table}\n"
  else
    puts "\033[31mНет доступных пользователей.\033[0m"
    return
  end
  
  # Запрашиваем ID пользователей
  puts "\nВведите ID пользователей через точку с запятой (;):"
  user_ids_input = gets.chomp
  
  user_ids = user_ids_input.split(';').map(&:strip)
  
  # Проверяем корректность ID пользователей
  invalid_users = user_ids.reject { |id| user_map.key?(id) }
  if invalid_users.any?
    puts "\033[31mСледующие ID пользователей не найдены: #{invalid_users.join(', ')}\033[0m"
    return
  end
  
  # Создаем временный CSV файл
  temp_file = 'temp_users_to_chats.csv'
  CSV.open(temp_file, 'w') do |csv|
    csv << ['user_id', 'user_name', 'chat_id', 'chat_name']
    user_ids.each do |user_id|
      csv << [user_id, user_map[user_id], chat_id, chat_map[chat_id]]
    end
  end
  
  # Спрашиваем про уведомление
  puts "\nСоздать системное уведомление при добавлении пользователей? (д/н):"
  notify = gets.chomp.downcase == 'д'
  
  # Добавляем пользователей
  puts "\n\033[33mДобавляем пользователей в чат #{chat_map[chat_id]}...\033[0m"
  results = integration.add_users_to_chats(temp_file, notify)
  
  # Выводим результаты
  puts "\n\033[32mРезультаты:\033[0m"
  puts "#{results[:success].size} пользователей успешно добавлено в чат"
  puts "#{results[:error].size} ошибок произошло"
  
  if results[:success].any?
    puts "\n\033[32mУспешно добавлены:\033[0m"
    results[:success].each do |result|
      puts "- #{result[:user_name]} (ID: #{result[:user_id]}) в чат #{result[:chat_name]} (ID: #{result[:chat_id]})"
    end
  end
  
  if results[:error].any?
    puts "\n\033[31mОшибки:\033[0m"
    results[:error].each do |result|
      puts "- Не удалось добавить пользователя #{result[:user_id]} в чат #{result[:chat_id]}: #{result[:error]}"
    end
  end
  
  # Удаляем временный файл
  File.delete(temp_file) if File.exist?(temp_file)
end

# Функция для интерактивного добавления тегов в чаты
def add_tags_to_chats_interactive(integration)
  puts "\n\033[33mДобавление тегов в чаты\033[0m"
  
  # Проверяем наличие файлов со списками
  tags_file = 'tags_list.csv'
  chats_file = 'group_chats_list.csv'
  
  unless File.exist?(tags_file)
    puts "\033[31mФайл со списком тегов не найден. Сначала выгрузите список тегов (пункт 2).\033[0m"
    return
  end
  
  unless File.exist?(chats_file)
    puts "\033[31mФайл со списком чатов не найден. Сначала выгрузите список групповых чатов (пункт 3).\033[0m"
    return
  end
  
  # Показываем список чатов
  puts "\n\033[36mДоступные групповые чаты:\033[0m"
  chat_rows = []
  chat_map = {}
  
  CSV.foreach(chats_file, headers: true) do |row|
    chat_id = row['chat_id']
    chat_name = row['chat_name']
    chat_rows << [chat_id, chat_name]
    chat_map[chat_id] = chat_name
  end
  
  if chat_rows.any?
    table = Terminal::Table.new(
      title: "Групповые чаты",
      headings: ['ID', 'Название чата'],
      rows: chat_rows
    )
    puts "\n#{table}\n"
  else
    puts "\033[31mНет доступных групповых чатов.\033[0m"
    return
  end
  
  # Запрашиваем ID чата
  puts "\nВведите ID чата, в который нужно добавить теги:"
  chat_id = gets.chomp
  
  unless chat_map.key?(chat_id)
    puts "\033[31mЧат с ID #{chat_id} не найден.\033[0m"
    return
  end
  
  # Показываем список тегов
  puts "\n\033[36mДоступные теги:\033[0m"
  tag_rows = []
  tag_map = {}
  
  CSV.foreach(tags_file, headers: true) do |row|
    tag_id = row['tag_id']
    tag_name = row['tag_name']
    tag_rows << [tag_id, tag_name]
    tag_map[tag_id] = tag_name
  end
  
  if tag_rows.any?
    table = Terminal::Table.new(
      title: "Теги",
      headings: ['ID', 'Название тега'],
      rows: tag_rows
    )
    puts "\n#{table}\n"
  else
    puts "\033[31mНет доступных тегов.\033[0m"
    return
  end
  
  # Запрашиваем ID тегов
  puts "\nВведите ID тегов через точку с запятой (;):"
  tag_ids_input = gets.chomp
  
  tag_ids = tag_ids_input.split(';').map(&:strip)
  
  # Проверяем корректность ID тегов
  invalid_tags = tag_ids.reject { |id| tag_map.key?(id) }
  if invalid_tags.any?
    puts "\033[31mСледующие ID тегов не найдены: #{invalid_tags.join(', ')}\033[0m"
    return
  end
  
  # Создаем временный CSV файл
  temp_file = 'temp_tags_to_chats.csv'
  CSV.open(temp_file, 'w') do |csv|
    csv << ['tag_id', 'tag_name', 'chat_id', 'chat_name']
    tag_ids.each do |tag_id|
      csv << [tag_id, tag_map[tag_id], chat_id, chat_map[chat_id]]
    end
  end
  
  # Добавляем теги
  puts "\n\033[33mДобавляем теги в чат #{chat_map[chat_id]}...\033[0m"
  results = integration.add_tags_to_chats(temp_file)
  
  # Выводим результаты
  puts "\n\033[32mРезультаты:\033[0m"
  puts "#{results[:success].size} тегов успешно добавлено в чат"
  puts "#{results[:error].size} ошибок произошло"
  
  if results[:success].any?
    puts "\n\033[32mУспешно добавлены:\033[0m"
    results[:success].each do |result|
      puts "- #{result[:tag_name]} (ID: #{result[:tag_id]}) к чату #{result[:chat_name]} (ID: #{result[:chat_id]})"
    end
  end
  
  if results[:error].any?
    puts "\n\033[31mОшибки:\033[0m"
    results[:error].each do |result|
      puts "- Не удалось добавить тег #{result[:tag_id]} к чату #{result[:chat_id]}: #{result[:error]}"
    end
  end
  
  # Удаляем временный файл
  File.delete(temp_file) if File.exist?(temp_file)
end

# Функция для отображения главного меню
def show_main_menu
  puts "\n\033[1;36m============================================\033[0m"
  puts "\033[1;36m   УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ И ТЕГАМИ В ПАЧКЕ\033[0m"
  puts "\033[1;36m============================================\033[0m"
  puts "\n\033[1mВыберите действие:\033[0m"
  puts "\033[36m1.\033[0m Выгрузить список всех пользователей пространства"
  puts "\033[36m2.\033[0m Выгрузить список всех тегов пространства"
  puts "\033[36m3.\033[0m Выгрузить список всех групповых чатов пространства"
  puts "\033[36m4.\033[0m Добавить пользователей в чаты (из Терминала)"
  puts "\033[36m5.\033[0m Добавить теги в чаты (из Терминала)"
  puts "\033[36m6.\033[0m Добавить пользователей в чаты (из таблицы)"
  puts "\033[36m7.\033[0m Добавить теги в чаты (из таблицы)"
  puts "\033[36m0.\033[0m Выход"
  print "\nВаш выбор: "
end

# Главная функция
def main
  # Проверяем API токен
  unless check_api_token
    exit 1
  end
  
  # Инициализируем интеграцию
  integration = initialize_integration
  unless integration
    exit 1
  end
  
  loop do
    # Показываем главное меню
    show_main_menu
    
    # Получаем выбор пользователя
    choice = gets.chomp
    
    case choice
    when '1'
      export_users_list(integration)
    when '2'
      export_tags_list(integration)
    when '3'
      export_group_chats_list(integration)
    when '4'
      add_users_to_chats_interactive(integration)
    when '5'
      add_tags_to_chats_interactive(integration)
    when '6'
      add_users_from_table(integration)
    when '7'
      add_tags_from_table(integration)
    when '0'
      puts "\n\033[32mДо свидания!\033[0m"
      break
    else
      puts "\n\033[31mНеверный выбор. Пожалуйста, выберите один из пунктов меню.\033[0m"
    end
    
    # Пауза перед возвратом в меню
    puts "\nНажмите Enter для возврата в главное меню..."
    begin
      # Используем Timeout для предотвращения зависания при автоматическом запуске
      require 'timeout'
      Timeout.timeout(0.5) { STDIN.gets }
    rescue Timeout::Error
      # Если таймаут, просто продолжаем
    end
  end
end

# Запускаем программу
main
