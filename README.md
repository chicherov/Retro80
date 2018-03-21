# Ретро КР580
Проект «**Ретро КР580**» — эмулятор некоторых, интересных мне, отечественных бытовых компьютеров 80-ых годов прошлого века.
Эмулятор полностью написан на **Objective-C**, является документ-ориентированным приложением **macOS** и требует для своей работы *как минимум OS X Lion (10.7)*.

## Поддерживаемые компьютеры
### Радио-86РК
- Доработка из журнала Радио №11/1987: параллельно второму КР580ВВ55 подключен таймер КР580ВИ53, возможна только запись. Канал 0 используется для генерации звука, каналы 1 и 2 для определения длительности звучания.
- Доработка из журнала Радиолюбитель №10/1992: контроллер «Самоцвет-М» (М.Акименко). Поддержка атрибутов цвета и инверсии для КР580ВГ75, правит один байт в Мониторе, поэтому после подключения или отключения желательно выполнить сброс.
- Доработка из журнала Радиолюбитель №4/1992: Поддержка атрибутов цвета для КР580ВГ75 от Л.Толкалина.
- Контролер накопителя на гибких магнитных дисках из журналов Радио №1 и №2/1993. ДОС версии 2.95.
- Эмуляция ROM-диска и SD-контролера [86RKSD](https://github.com/alemorf/retro/tree/master/radio_86rk-sd_controller).
### Микроша
- Модуль НГМД: аналогичен варианту для Радио-86РК и полностью с ним совместим.
- Модуль ОЗУ: дополнительные 16Кб ОЗУ в области 8000-BFFF.
- Контролер цвета.
### Партнер 01.01
- Модуль цветной псевдографический (МЦПГ) «Партнёр-01.61».
- Модуль контроллера дисковода «Партнёр-01.51».
### Апогей БК-01
- Оригинальный «Апогей БК-01» и модификация «Апогей БК-01Ц» с поддержкой цвета.
- Эмуляция ROM-диска, [49LF0x0](https://github.com/alemorf/retro/tree/master/apogee_bk01-rom_disk/49lf0x0) и SD-контролера [86RKSD](https://github.com/alemorf/retro/tree/master/radio_86rk-sd_controller).
### Микро-80
- Минимальная конфигурация: 2Кб ПЗУ (Монитор), 2Кб статического ОЗУ пользователя и 2Кб (2048x7бит + 2048x1бит) ОЗУ дисплейного модуля, доступного процессору только для записи.
- Дополнительные 16/32/48 или 60Кб динамического ОЗУ. В максимальной конфигурации динамическое ОЗУ пересекается с областью ОЗУ дисплейного модуля, тем самым дублирует его и позволяет читать записаное в область экрана значение.
- Доработка из журнала Радио №11/1989: монитор «М/80К», совместимый с Радио-86РК.
    + Доработка из журнала Радио №2/1987: чтение из ОЗУ дисплейного модуля.
    + Дополнительная КР580ВВ55 для чтения данных из внешнего ПЗУ.
    + Эмуляция ROM-диска и SD-контролера 86RKSD
### ЮТ-88
- Минимальная конфигурация: 1Кб ПЗУ (Монитор-0), 1Кб статического ОЗУ монитора 0, вывод информации на 6-разрядный семисегментный светодиодный индикатор (в строке состояния), ввод информации с клавиатуры из 17 клавиш (16 шестнадцатеричных символов и Backspace).
- Полная конфигурация: Дисплейный модуль, 2Кб ПЗУ (Монитор-F), 1Кб статического ОЗУ монитора F.
- Дополнительные 4Кб статического ОЗУ или 64Кб динамического ОЗУ.
- Квазидиск 64/128/192 или 256Кб для запуска CP/M.
- Эмуляция ROM-диска и SD-контролера 86RKSD.
- Таймер КР580ВИ53 на портах 50-5F.
### Специалист
* Варианты:
    + Монитор-1 (Оригинальный)
    + Монитор-2 (Расширенный)
    + Монитор ПЭВМ «ЛИК»
    + Монитор SP580
    + Монитор 2.7 (Ленинград-90)
    + Монитор 3.3 (Ленинград-91)
### Специалист-MX
* Специалист MX (RAMFOS)
* Специалист MX (MXOS)
### Специалист-MX2
### Орион-128
* Разные схемы подключения контролера НГМД (F7x0-F7x3, регистр управления F708/F714/F720).
* Поддержка разрешений 480x256 и 400x256 (в монохромных режимах, драйвер 80.com).
* КР580ВИ53 по схеме Радио-86РК по вдресам F740-F75F.
* Варианты:
    + Монитор-1 (Отладочный): по умолчанию 128Кб памяти и ORDOS 2.4.
    + Монитор-2 (Основной): по умолчанию 256Кб памяти и ORDOS 4.03.
    + Монитор-3: при старте из ROM-диска загружается M3-EXT 1.3.
    + Z80Card V3.1: поддержка Z80 от Орион-Сервис, фактически стандартный Орион, но с процессором Z80.
    + Z80Card V3.2: стандартный Орион с процессором Z80 3,5МГц (5МГц с WAIT).
    + Z80Card-II, Ленинградский вариант поддержки Z80: Z80 5Мгц.
        + Полное ОЗУ 64Кб, диспечер ОЗУ 16Кб, прерывания 50Hz, звук FF (Togglesound) и FE (ZX-Sound).
        + Два варианта монитора 3.2: (загрузка с ROM-диска) и 3.3 (загрузка с дискеты).
        + Поддержка ROM-диска до 1Мб (порт FE).


## Встроенный отладчик
Эмуляцию можно в любой момент приостановить для отладки с помощью сочетания клавиш ⌘D.
Появится консоль отладчика, в которую будут выведены текущее содержимое регистров процессора, инструкция, находящиеся по адресу PC и приглашение к вводу команды.

## Клавиатура
Два режима работы клавиатуры.
В режиме «QWERTY» алфавитно-цифровые клавиши в целом соответствуют надписям над ними.
Набирать текст можно точно так же, как и в других приложениях macOS, в том числе вставлять текст из буфера обмена.
В зависимости от набранного символа эмулируется нажатие соответствующей клавиши в нужном регистре.
* [ВК] это **[Return ⏎]**, [ПС] — **[Enter ⌤]** или **[fn] + [Return ⏎]**.
* [СТР] — **[Delete ⌦]** или **[fn] + [Backspace ⌫]**
* [↖] — **[fn] + [←]**
* [СС] — **[Shift ⇧]**, в режиме «QWERTY» может игнорироваться.
* [УС] — **[Control]**
* [РУС/ЛАТ] — **[Option ⌥]** или **[Capslock ⇪]** для Микро-80/ЮТ-88
