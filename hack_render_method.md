```bash
rails new HackRails
rvm --ruby-version use 2.1.10@rails4
rails plugin new pdf_renderer
```

Эта команда, кроме прочих файлов создает самостоятельную версию Rails приложения
в test/dummy, которая позволит запускать тесты в контексте этого приложения

pdf_renderer.gemspec включает в себя базовую спецификацию гема: авторы, версия,
зависимости и т.д.

Rakefile создает базовые задачи по запуску тестов, генерирования документации и
публикации гема. Список команд:
```bash
arkweid@ubuntu:~/RailsProjects/HackRails/pdf_renderer$ rake -T
```
rake build            # Build pdf_renderer-0.0.1.gem into the pkg directory
rake clobber_rdoc     # Remove RDoc HTML files
rake install          # Build and install pdf_renderer-0.0.1.gem into system gems
rake install:local    # Build and install pdf_renderer-0.0.1.gem into system gems without network access
rake rdoc             # Build RDoc HTML files
rake release[remote]  # Create tag v0.0.1 and build and push pdf_renderer-0.0.1.gem to Rubygems
rake rerdoc           # Rebuild RDoc HTML files
rake test             # Run tests


Посмотрим, чем boor.rb отличается от обычного:
```ruby
$LOAD_PATH.unshift File.expand_path('../../../../lib', __FILE__)
```
Эта строчка добавляет lib директорию плагина в список загрузки руби, что делает
наш плагин доступным в макете приложения(dummy)

Проверим, что все работает:
```bash
arkweid@ubuntu:~/RailsProjects/HackRails/pdf_renderer$ rake test
```
Теперь о рендерере. Он позволяет специфицировать свое поведение с помощью метода
render()

rails/actionpack/lib/action_controller/metal/renderers.rb
```ruby
add :json do |json, options|
  json = json.to_json(options) unless json.kind_of?(String)
  if options[:callback].present?
    self.content_type ||= Mime::JS
    "#{options[:callback]}(#{json})"
  else
    self.content_type ||= Mime::JSON
    json
  end
end
```

Например, так:
```ruby
render json: @post
```
Эта команда вызовет блок кода под `add :json do |json, options|`
Тут json = @post
А options будет содержать хэш опций, в данном примере пустой

 По итогу по хотим что-нибудь такое:
 ```ruby
 render pdf: 'contents', template: 'path/to/template'
 ```
Поехали!
../pdf_renderer.gemspec
```ruby
s.add_dependency "prawn", "2.2.2"
```

Проверим, стартуем консоль и набираем:
```ruby
require "prawn"

pdf = Prawn::Document.new
pdf.text("A PDF in four lines of code")
pdf.render_file("sample.pdf")
```

Выходим и видим что в корневой папке появился файл

Добавим контроллер:
/test/dummy/app/controllers/home_controller.rb
```ruby
class HomeController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.pdf { render pdf: "contents" }
    end
  end
end
```
Забацаем тесты:
Проверим заголовок и имя файла как аттачмент
/test/integration/pdf_delivery_test.rb
```ruby
require "test_helper"

class PdfDeliveryTest < ActionDispatch::IntegrationTest
  test "pdf request sends a pdf as file" do
    get home_path(format: :pdf)

    assert_match "PDF", response.body
    assert_equal "binary", headers["Content-Transfer-Encoding"]

    assert_equal "attachment; filename=\"contents.pdf\"",
    headers["Content-Disposition"]
    assert_equal "application/pdf", headers["Content-Type"]
  end
end
```
Естественно получаем ошибку:
1) Failure:
PdfDeliveryTest#test_pdf_request_sends_a_pdf_as_file [/home/arkweid/RailsProjects/HackRails/pdf_renderer/test/dummy/pdf_delivery_test.rb:7]:
Expected /PDF/ to match "This template is rendered with Prawn.\n".

Теперь сделаем, чтобы оно работало:
/lib/pdf_renderer.rb
```ruby
require "prawn"

ActionController::Renderers.add :pdf do |filename, options|
  pdf = Prawn::Document.new
  pdf.text render_to_string(options)
  send_data(pdf.render, filename: "#{filename}.pdf", disposition: "attachment")
end
```
Создали новый документ, закинули туда некоторый текст и с помощью
метода send_data() доступного в рельсах оправляем его клиенту. Готово!
Тесты проходят, пдфка отправляется. Однако один момент который требует пояснения.
Мы не манипулировали заголовком, однако Content-Type у нас application/pdf.
И вот почему. Заглянем сюда:
/actionpack/lib/action_dispatch/http/mime_types.rb
И видим там строчку:
```ruby
Mime::Type.register "application/pdf", :pdf, [], %w(pdf)
```
Когда рельса получает запрос `/home.pdf` она извлекает формат(pdf) из URL,
сверяется с `format.pdf`, объявленный в `HomeController#index`, и устанавливает
соответствующий `content type`, прежде чем вызвать `render()`
