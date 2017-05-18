# encoding: UTF-8


# ******************************************
# Возвращай один тип объекта из функции, page 209
# ******************************************
# Пусть у тебя есть метод, который может вернуть nil, если ничего не найдено
# Он же может вернуть 'string', если всего один объект в результате или
# массив ['string', 'string', ...]
# Так вот, не надо так. Пусть лучше он всегда возвращает массив.
# Пустой или с одним объектом. Поверь, Люк.

# ******************************************
# Call back instead of returning, page 217
# ******************************************
# Вместо проверки на успешность/не успешность действия использовать коллбек.
# Он будет выполнен, если действие успешно.

def import_purchase(date, title, user_email, &import_callback)
  user = User.find_by_email(user_email)
  unless user.purchased_titles.include?(title)
    purchase = user.purchases.create(title: title, purchased_at:
    date)
    import_callback.call(user, purchase)
  end
end

import_purchase(date, title, user_email) do |user, purchase|
  send_book_invitation_email(user.email, purchase.title)
end

# Так же, такой код будет легко переделать под операции над множеством.

import_purchases(purchase_data) do |user, purchase|
  send_book_invitation_email(user.email, purchase.title)
end


# ******************************************
# Represent failure with a special case object, page 222
# ******************************************

def current_user
  if session[:user_id]
    User.find(session[:user_id])
  else
    GuestUser.new(session)
  end
end

# ******************************************
# 4.5 Return a status object, page 224
# ******************************************

# Определим статусный класс, который бы позволил нам удобно обрабатывать
# ошибку/успех/неуспех
class ImportStatus
  def self.success() new(:success) end
  def self.redundant() new(:redundant) end
  def self.failed(error) new(:failed, error) end

  attr_reader :error

  def initialize(status, error = nil)
    @status = status
    @error = error
  end

  def success?
    @status == :success
  end

  def redundant?
    @status == :redundant
  end

  def failed?
    @status == :failed
  end
end

# Теперь используем этот класс в методе оплаты

def import_purchase(date, title, user_email)
  user = User.find_by_email(user_email)
  if user.purchased_titles.include?(title)
    ImportStatus.redundant
  else
    user.purchases.create(title: title, purchased_at: date)
    ImportStatus.success
  end

rescue => error
  ImportStatus.failed(error)
end

# Теперь мы можем пользоваться этим так:

result = import_purchase(date, title, user_email)
if result.success?
  send_book_invitation_email(user_email, title)
elsif result.redundant?
  logger.info "Skipped #{title} for #{user_email}"
else
  logger.error "Error importing #{title} for #{user_email}:#{result.error}"
end

# ******************************************
# Переделывание под использование серии коллбеков
# ******************************************

class ImportStatus
  def self.success() new(:success) end
  def self.redundant() new(:redundant) end
  def self.failed(error) new(:failed, error) end

  attr_reader :error

  def initialize(status, error = nil)
    @status = status
    @error = error
  end

  def on_success
    yield if @status == :success
  end

  def on_redundant
    yield if @status == :redundant
  end

  def on_failed
    yield(error) if @status == :failed
  end
end

def import_purchase(date, title, user_email)
  user = User.find_by_email(user_email)
  if user.purchased_titles.include?(title)
    yield(ImportStatus.redundant)
  else
    user.purchases.create(title: title, purchased_at: date)
    yield(ImportStatus.success)
  end
rescue => error
  yield(ImportStatus.failed(error))
end

# Теперь клиентский код будет выглядеть так:

import_purchase(date, title, user_email) do |result|
  result.on_success do
    send_book_invitation_email(user_email, title)
  end
  result.on_redundant do
    logger.info "Skipped #{title} for #{user_email}"
  end
  result.on_error do |error|
    logger.error "Error importing #{title} for #{user_email}:#{error}"
  end
end

# ******************************************
# Сигнал что пора заканчивать catch/throw vs Handling failure, page 227
# ******************************************
# Допустим, мы парсим файл и нам нужно знать какому-нибудь методу парсера,
# что нужно прерваться и продолжить, данных у нас достаточно

class DoneException < StandardError; end

if count_it && @current_length + string.length > @length
# ...
  raise DoneException.new
end

begin
  parser.parse(html) unless html.nil?
rescue DoneException
  # we are done
end

# Такой код можно переделать под использование catch/throw
if count_it && @current_length + string.length > @length
  # ...
  throw :done
end

# ...
catch(:done)
  parser.parse(html) unless html.nil?
end

# ******************************************
# Bouncer method
# ******************************************

def filter_through_pipe(command, message)
  result = checked_popen(command, "w+", ->{message}) do |process|
    process.write(message)
    process.close_write
    process.read
  end
  check_child_exit_status  # <-- Bouncer method
  result
end

def check_child_exit_status
  unless $?.success?
    raise ArgumentError, "Command exited with status #{$?.exitstatus}"
  end
end

# Его можно переписать под использование блока
def check_child_exit_status
  result = yield
    unless $?.success?
      raise ArgumentError, "Command exited with status #{$?.exitstatus}"
    end
  result
end

# Теперь клиентский код будет выглядеть так:
def filter_through_pipe(command, message)
  check_child_exit_status do
    checked_popen(command, "w+", ->{message}) do |process|
      process.write(message)
      process.close_write
      process.read
    end
  end
end

# ******************************************
# Risky operation checker
# ******************************************

def filter_through_pipe(command, message)
  results = nil
  IO.popen(command, "w+") do |process|
    results =
      begin
        process.write(message)
        process.close_write
        process.read
      rescue Errno::EPIPE
        message
      end
  end
  results
end

# Добавим такой метод
def checked_popen(command, mode, error_policy = -> { raise })
  IO.popen(command, mode) do |process|
    return yield(process)
  end
rescue Errno::EPIPE
  error_policy.call
end

# И переделаем оригинальный
# Если произойдет ошибка, то error_policy просто вернет оригинальное сообщение
# В противном случае, если мы не будем переопределять error_policy,
# то произойдет исключение
def filter_through_pipe(command, message)
  checked_popen(command, "w+", -> { message }) do |process|
    process.write(message)
    process.close_write
    process.read
  end
end
