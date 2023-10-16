create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as		-- Необходима пустая строка после
set nocount on		-- Необходим отступ
begin
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	declare @ErrorMessage varchar(max) 		-- declare используется один раз, переменные стоит перечислять через запятую

-- Проверка на корректность загрузки   (пропущен отступ в начале строки)
	if not exists (
	select 1		-- Необходим отступ для всего блока кода, до закрытия скобки if
	from syn.ImportFile as f
	where f.ID = @ID_Record
		and f.FlagLoaded = cast(1 as bit)
	)
		begin		-- Должен быть на одном уровне с if
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'
			-- Пустая строка не нужна
			raiserror(@ErrorMessage, 3, 1)
			return
		end

	CREATE TABLE #ProcessedRows (		-- Оператор должен быть записан в нижнем регистре
		ActionType varchar(255),
		ID int
	)
	
	--Чтение из слоя временных данных  (Отсутствует пробел между -- и комментарием)
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive --логическая переменная?
	into #CustomerSeasonal
	from syn.SA_CustomerSeasonal cs		-- Отсутствует алиас
		join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = cs.Season
		join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		join syn.CustomerSystemType as cst on cs.CustomerSystemType = cst.Name -- Сначала имя поля присоединяемой таблицы
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи			(Для многострочных комментариев используется конструкция 0/* */)
	-- Добавляем причину, по которой запись считается некорректной
	select
		cs.*
		,case
			when cc.ID is null
				then 'UID клиента отсутствует в справочнике "Клиент"' -- Результат записывается на следующей строчке с одним отступом от when
			when cd.ID is null then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, 0) as bit) is null then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows -- Необходим отступ, потому что into относится к ператору select
	from syn.SA_CustomerSeasonal as cs
	left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer		-- Все виды join пишутся с одним отступом
		and cc.ID_mapping_DataSource = 1
	left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor and cd.ID_mapping_DataSource = 1 -- and с отступом от join
	left join dbo.Season as s on s.Name = cs.Season
	left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, 0) as bit) is null
		
end
