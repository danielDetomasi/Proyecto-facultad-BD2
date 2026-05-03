Create DataBase TorneosKite
use TorneosKite

set dateformat MDY;--seteo formato fecha mes,dia,año

-- Creación de la tabla Locacion
CREATE TABLE Locacion(
locID INT NOT NULL,
pais VARCHAR(100) NOT NULL,
ciudad VARCHAR(100)
);

--Creación de la tabla Torneo
CREATE TABLE Torneo (
torneoID INT not null,
nombre VARCHAR(100) NOT NULL,
fecha DATE,
locID INT,
tipo VARCHAR(50),
estado VARCHAR(50),
Nivel INT
);

--Creación de la tabla Participante
CREATE TABLE Participante (
participanteID INT NOT NULL,
nombre VARCHAR(100),
locID INT,
fecha_nacimiento DATE,
experiencia INT  
);

--Creación de la tabla Inscripcion
CREATE TABLE Inscripcion (
inscripcionID INT IDENTITY,
torneoID INT,
participanteID INT,
posicion INT,
);

--Creación de la tabla auxiliar puesto_puntos (asumiendo dos columnas, puesto y puntos)
CREATE TABLE puesto_puntos (
puesto INT,
puntos INT
);

--Creación de la tabla auditoria (implementar despues)
CREATE TABLE AuditInscripcion(
AuditID int identity not null,
AuditFecha datetime,
AuditHost varchar(30),
posAnterior decimal,
posActual decimal);

--tabla que guarda participantes que no se pudieron inscribir al torneo por nivel
create table participanteNoNivel(
nombre varchar(100) not null,
participanteID int not null,
torneoID int not null);


--restricciones de las tablas generales
alter table puesto_puntos 
	alter column puesto int not null;

alter table Torneo
	drop column torneoID;

alter table Torneo
	add torneoID int identity not null;

alter table Torneo
	alter column fecha date not null;

alter table Inscripcion
	alter column torneoID int not null;

alter table Participante
	drop column participanteID;

alter table Participante
	add participanteID int identity not null;

alter table Participante
	add puntosAnuales int;

--Seccion alter table primary key
alter table Locacion 
	add constraint PK_Locacion primary key(locID);

alter table Torneo 
	add constraint PK_Torneo primary key(torneoID);

alter table Participante 
	add constraint PK_Participante primary key(participanteID);

alter table Inscripcion 
	add constraint PK_Inscripcion primary key(inscripcionID);

alter table puesto_puntos
	add constraint PK_Puesto primary key(puesto);

alter table participanteNoNivel
	add constraint PK_PartitipcanteNivel primary key(participanteID,torneoID);

--foreign key
alter table Torneo
	add constraint FK_TorneoLocacion foreign key (locID) references Locacion(locID);

alter table Participante
	add constraint FK_ParticipanteLocacion foreign key (locID) references Locacion(locID);

alter table Inscripcion 
	add constraint FK_InscripcionTorneo foreign key (torneoID) references Torneo(torneoID);

alter table Inscripcion 
	add constraint FK_InscripcionParticipante foreign key (participanteID) references Participante(participanteID);

alter table Inscripcion
	add constraint FK_Puesto foreign key (posicion) references puesto_puntos(puesto);

alter table participanteNoNivel
	add constraint FK_PartitipcanteNivelParticipanteID foreign key(participanteID) references participante(participanteID);

alter table participanteNoNivel
	add constraint FK_PartitipcanteNivelTorneoID foreign key(torneoID) references torneo(torneoID);

--constraint de las tablas
--torneo
alter table Torneo
	add constraint CON_NombreFechaT unique(nombre,fecha);

alter table Torneo
	add constraint CON_NombreTorneo check(nombre not LIKE '%[0-9]%');

alter table Torneo
	add constraint CON_Fecha check (YEAR (fecha) >2016);

alter table Torneo
	add constraint CON_Tipo check (tipo in ('freestyle','kite-surf','parkstyle','racing'));

alter table Torneo
	add constraint CON_Estado check (estado in ('planificado','en competencia','finalizado','cancelado'));

alter table Torneo
	add constraint CON_Nivel check (Nivel >0 and Nivel<11);

--participante
alter table Participante
	add constraint CON_Nombre unique(nombre);

alter table Participante
	add constraint CON_Experiencia check (experiencia >=0 and experiencia <=10);

alter table Participante
	add constraint CON_Edad check (datediff(year,fecha_nacimiento,getdate())>=18);

--inscripcion
alter table Inscripcion
	add constraint CON_Pos check(posicion > 0 and posicion < 15);

alter table Inscripcion
	add constraint CON_Par unique(torneoID,participanteID);

alter table Inscripcion 
	add constraint CON_PosTor unique(torneoID,posicion);

--locacion
alter table Locacion
	add constraint CON_CiudadPais  unique(pais,ciudad);

--INDICES
create index i_fk_TorneoLocacion on Torneo(locID);

create index i_fk_ParticipanetesLocacion on Participante(locID);

create index i_fk_InscripcionTorneo on Inscripcion(torneoID);

create index i_fk_InscripcionParticipante on Inscripcion(participanteID);

create index i_fk_InscripcionPosicion on Inscripcion(posicion);

create index i_ParticipanteNombre on Participante(nombre);

create index i_TorneoTipo on Torneo(tipo);

create index i_PuestoPuntosPuntos on puesto_puntos(puntos);

--triggers
--trigger a
--actualizar los puntos del participante 
CREATE TRIGGER PuntosPorAño
ON Inscripcion
AFTER INSERT
AS 
BEGIN

	DECLARE @AñoTorneo int
	set @AñoTorneo=(
	SELECT YEAR(t.fecha)
	from Torneo t
	join inserted i
	on t.torneoID=i.torneoID)

	DECLARE @Participante INT
	SET @Participante=(select i.participanteID
	from inserted i
	join Participante p
	on i.participanteID=p.participanteID)

	DECLARE @AñoActual INT
	SET @AñoActual=YEAR(GETDATE())

	DECLARE @PuntosTorneo INT
	SET @PuntosTorneo=(SELECT sum(pp.puntos)
	FROM puesto_puntos pp
	JOIN Inscripcion i
	on pp.puesto=i.posicion
	where @AñoTorneo=@AñoActual and i.participanteID=@Participante)

	IF(@AñoActual=@AñoTorneo)
	BEGIN
		UPDATE Participante 
		SET puntosAnuales=@PuntosTorneo
		WHERE participanteID=@Participante
	END
END

--trigger b
--crea un registro en la tabla AUDITINSCRIPCION cuando se hace un update de la posicion de una inscripcion
CREATE TRIGGER AuditPuesto ON Inscripcion
AFTER UPDATE 
AS 
BEGIN
	IF UPDATE(posicion)
		BEGIN 
			INSERT INTO AuditInscripcion
			SELECT
				GETDATE(),
				SYSTEM_USER,
				d.posicion AS posAnterior,
				i.posicion AS posActual
				FROM inserted i
				INNER JOIN deleted d 
				ON d.torneoID = i.torneoId AND d.participanteID = i.participanteID
		END
END

--trigger c
--controlar que el nivel del participante sea mayor al del torneo
CREATE TRIGGER controlarNivelParticipante ON Inscripcion
INSTEAD OF INSERT
AS
BEGIN 

	DECLARE @nombreK varchar(100)
	set @nombreK=(select p.nombre from Participante p join inserted on p.participanteID=inserted.participanteID)

	IF NOT EXISTS(
	--el select 1 comprueba que uno de los registros cumple con la condicion del if
		SELECT 1
		FROM inserted i
		JOIN Torneo t
		ON i.torneoID=t.torneoID
		JOIN Participante p
		ON i.participanteID=p.participanteID
		WHERE p.experiencia<t.Nivel
	)
	BEGIN 
		INSERT INTO Inscripcion(torneoID, participanteID, posicion)
		SELECT torneoID,participanteID,posicion
		FROM inserted
	END
	ELSE
	BEGIN 
		insert into participanteNoNivel(nombre,participanteID,torneoID)
		select @nombreK,participanteID,torneoID
		from inserted

		select * from participanteNoNivel
	END
END

--INSERTS 
--puesto_puntos
insert into puesto_puntos(puesto,puntos) values
(1 , 1000),
(2,870),
(3,770),
(4,700),
(5,580),
(6,580),
(7,580),
(8,580),
(9,420),
(10,420),
(11,420),
(12,420),
(13,280),
(14,245);

--INSERT ERRONEO
insert into puesto_puntos(puesto,puntos) values(1,900);--id duplicado

--locacion
insert into Locacion(locID,pais,ciudad) values
(1,'Brasil','Rio'),
(2,'Brasil','Sao Paulo'),
(3,'Mexico','Playa del Carmen'),
(4,'Uruguay','Rocha'),
(5,'Chile','Viña del Mar'),
(6,'EEUU','Miami');

--INSERTS ERRONEOS
insert into Locacion(locID,pais,ciudad)values--el pais y la ciudad duplicados
(7,'Brasil','Rio');

insert into Locacion(locID,pais,ciudad)values--id duplciado
(6,'Colombia','Cali');

--torneo
insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values
('freestyle Rio','01/01/2017',1,'freestyle','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values
('free Rio','01/01/2020',2,'freestyle','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Viento Caribeño','01/01/2021',3,'kite-surf','cancelado',3)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Kite Uruguay','01/01/2018',4,'parkstyle','cancelado',5)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo de Racing','05/05/2021',5,'racing','finalizado',8)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Segunda edicion torneo de Racing','05/21/2022',5,'racing','finalizado',8)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Miami Kite','05/21/2017',6,'kite-surf','finalizado',10)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo internacional','01/01/2022',3,'parkstyle','cancelado',4)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo principiantes','10/20/2023',4,'kite-surf','en competencia',1)

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo segunda edicion Uruguay','01/24/2024',4,'kite-surf','planificado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo Uruguay','01/24/2023',4,'kite-surf','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo anual de Kite_Surf','01/24/2021',4,'kite-surf','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values
('Torneo anual de Kite_Surf segunda edicion','01/01/2021',2,'kite-surf','finalizado',1);

--INSERT ERRONEO
insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--el nombre contiene numeros
('200 rio','01/01/2017',5,'freestyle','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--el nombre son solo numeros
('200','01/01/2017',5,'freestyle','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values
('rio 200','01/01/2017',5,'freestyle','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values
('r1o','01/01/2017',5,'freestyle','finalizado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--el tipo ingresado no existe
('rio','01/01/2017',5,'competencia','cancelado',1);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--el nivel debe estar entre 1 y 10
('rio','01/01/2017',5,'kite-surf','planificado',16);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--el estado ingresado no existe
('rio','01/01/2017',5,'kite-surf','en proceso',10);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--la locacion ingresada no existe
('rio','01/01/2017',100,'kite-surf','planificado',10);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel) values--torneo duplicado por su nombre y fecha
('freestyle Rio','01/01/2017',1,'kite-surf','planificado',10);

insert into Torneo(nombre,fecha,locID,tipo,estado,Nivel)values--la fecha ingresada es menor a la admitida
('Miami Kite','05/21/2015',6,'kite-surf','finalizado',10);

--participante
insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Pedro',1,'01/01/2005',6);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Joaquin',2,'01/28/2004',4);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Ana',6,'08/12/1988',7);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Marta',5,'01/01/2003',10);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Lola',3,'09/02/1990',6);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Agustin',4,'09/12/2000',2);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Federico',4,'09/20/1999',10);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Lucia',1,'07/10/2001',9);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values
('Camila',2,'10/20/1986',8);

--INSERT ERRONEO
insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values--nombre duplicado
('Pedro',1,'01/01/2006',6);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values--edad menor a 18
('Juan',16,'01/01/2006',6);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values--la exp debe estar entre 1 y 10
('Diego',1,'01/01/2006',16);

insert into Participante(nombre,locID,fecha_nacimiento,experiencia) values--la locacion no existe
('a',200,'10/20/1986',8);

--inscripcion

--INSCRIPCIONES A LOS TORNEOS DE 2021 CONSULTA 1

insert into Inscripcion(torneoID,participanteID,posicion)values(3,5,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(3,2,3);

insert into Inscripcion(torneoID,participanteID,posicion)values(3,1,10);

insert into Inscripcion(torneoID,participanteID,posicion)values(3,4,2);

insert into Inscripcion(torneoID,participanteID,posicion)values(5,4,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(5,7,2);

insert into Inscripcion(torneoID,participanteID,posicion)values(5,9,4);

insert into Inscripcion(torneoID,participanteID,posicion)values(12,4,1);

--INSCRIPCIOPES PARA LA CONSULTA 2

insert into Inscripcion(torneoID,participanteID,posicion)values(6,4,2);

insert into Inscripcion(torneoID,participanteID,posicion)values(7,4,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(7,7,2);

--INSCRIPCIONES PARA LA CONSULTA 5

insert into Inscripcion(torneoID,participanteID,posicion)values(10,4,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(11,4,10);

insert into Inscripcion(torneoID,participanteID,posicion)values(10,5,2);

insert into Inscripcion(torneoID,participanteID,posicion)values(11,5,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(3,7,4);

insert into Inscripcion(torneoID,participanteID,posicion)values(12,7,2);

insert into Inscripcion(torneoID,participanteID,posicion)values(13,7,1);

--INSCRIPCIONES PARA PROCEDIMIENTO C 

insert into Inscripcion(torneoID,participanteID,posicion)values(8,1,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(8,3,2);

insert into Inscripcion(torneoID,participanteID,posicion)values(8,4,5);

insert into Inscripcion(torneoID,participanteID,posicion)values(8,5,9);

--INSERT PARA EL TRIGGER A
insert into Inscripcion(torneoID,participanteID,posicion)values(9,1,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(11,1,3);

insert into Inscripcion(torneoID,participanteID,posicion)values(9,4,10);

--UPDATE para probar el trigger
UPDATE Inscripcion
	SET posicion = 11
	WHERE torneoID = 3 and participanteID = 1;

--insert erroneo
insert into Inscripcion(torneoID,participanteID,posicion) values(1,200,1);--el participante no existe

insert into Inscripcion(torneoID,participanteID,posicion) values(600,1,1);--el torneo no existe

insert into Inscripcion(torneoID,participanteID,posicion) values(1,1,15);--la posicion debe estar entre 1 y 14

insert into Inscripcion(torneoID,participanteID,posicion)values(9,4,12);--el participante ya se inscribio a ese torneo

--INSERTS PARA LA TABLA DEL TRIGGER C

insert into Inscripcion(torneoID,participanteID,posicion)values(6,6,1)--el participante tiene un nivel menor al del torneo

insert into Inscripcion(torneoID,participanteID,posicion)values(7,1,1);

insert into Inscripcion(torneoID,participanteID,posicion)values(7,2,2);

--

insert into Inscripcion(torneoID,participanteID,posicion)values(3,8,1);--el torneo ya cuenta con un participante en esa posicion


--mostrar datos de las tablas
select * from puesto_puntos;

select * from Locacion;

select * from Torneo;

select * from Participante;

select * from Inscripcion;

select * from AuditInscripcion;

select * from participanteNoNivel;

--consulta 1
--mostrar datos de los participantes segun el tipo de torneo de 2021
select p.nombre,sum(pp.puntos)as total_puntos,t.tipo from Participante p
join Inscripcion i
on p.participanteID=i.participanteID
join puesto_puntos pp
on i.posicion=pp.puesto
join Torneo t
on i.torneoID=t.torneoID
where t.fecha between '01/01/2021' and '12/31/2021'
group by t.tipo,p.nombre;


--consulta 2 
--mostrar maximo,minimo y promedio de puntos de cada participante segun el tipo de torneo 
select p.nombre,t.tipo,max(pp.puntos)as maximo,avg(pp.puntos)as  promedio,min(pp.puntos)as minimo
from Participante p
join Inscripcion i
on p.participanteID=i.participanteID
join Torneo t
on i.torneoID=t.torneoID
join puesto_puntos pp
on i.posicion=pp.puesto
group by p.nombre,t.tipo;


--consulta 3
--mostrar los participantes de los torneos que tengan al menos un finalizado
select t.estado,t.nombre,t.fecha,t.tipo,t.Nivel,l.pais,l.ciudad,count(i.torneoID)as cantidad_Participantes
from Torneo t
join Locacion l
on t.locID=l.locID
join Inscripcion i
on t.torneoID=i.torneoID
where t.estado not like 'cancelado'
group by t.estado,t.nombre,t.fecha,t.tipo,t.Nivel,l.pais,l.ciudad;

--consulta 4
--mostrar participantes de torneos de los ultimos dos años y que no son del tipo racing 
select p.*,t.tipo,t.torneoID from Participante p
join Inscripcion i
on p.participanteID=i.participanteID
join Torneo t
on i.torneoID=t.torneoID
where t.fecha >= dateadd(year, -2,GETDATE())
		and t.tipo not in(select tipo from Torneo 
							where tipo like 'racing');
						
--consulta 5
--mostrar los participantes que tengan 1200 puntos y mas de 3 inscripciones en free y kite en un año
SELECT p.nombre AS Kiter,       
       SUM(pp.puntos) AS PuntosAcumulados,
       COUNT(i.inscripcionID) AS Inscripciones
FROM Participante p
JOIN Inscripcion i ON p.participanteID = i.participanteID
JOIN Torneo t ON i.torneoID = t.torneoID
join puesto_puntos pp on i.posicion=pp.puesto
WHERE t.tipo IN ('freestyle', 'kite-surf')
GROUP BY p.nombre,YEAR(t.fecha)
HAVING SUM(pp.puntos) > 1200
   AND COUNT(i.inscripcionID) >= 3;

--consulta 6
--mostrar torneo con mas participantes que no sea en brasil ni tenga genadores brasileños
select top 1 t.torneoID,t.estado,t.fecha,t.Nivel,t.nombre,t.tipo,COUNT(i.inscripcionID)as Participantes from Torneo t
join Locacion l
on t.locID=l.locID
join Inscripcion i
on t.torneoID=i.torneoID
join Participante p
on I.participanteID=p.participanteID
where t.fecha >= dateadd(year, -5,getdate() ) and l.pais not like('Brasil')
and p.participanteID not in(select p.participanteID from Participante join Locacion l
on p.locID=l.locID 
join Inscripcion i
on p.participanteID=i.participanteID
where l.pais like 'Brasil' and i.posicion=1)
group by t.torneoID,t.estado,t.fecha,t.Nivel,t.nombre,t.tipo
order by Participantes desc;

--FUNCIONES Y PROCEDIMIENTOS

--RETORNA LA CANTIDAD DE PRIMEROS PUESTOS DE UN PARTICIPANTE
CREATE OR ALTER FUNCTION dbo.primerPuesto(@idparticipante int) 
returns int
as
begin
	declare @contador int
	set @contador=0
		select @contador=count(distinct t.torneoID) 
		from Torneo t
		join Inscripcion i
		on t.torneoID=i.torneoID
		join Participante p
		on i.participanteID=p.participanteID
		where @idparticipante=p.participanteID and i.posicion=1

		return @contador 
end;

select dbo.primerPuesto(4) as primeros_puestos--la participante 4 tiene 3 primeros puestos

--RETORNA LA CANTIDAD DE PARTICIPANTES ANOTADOS A TORNEOS DEL MISMO PAIS 
CREATE OR ALTER FUNCTION dbo.participantesPais(@idTorneo int)
returns int
as
begin
	declare @paisT varchar(100)
	declare @cantP int
	set @cantP=0

	select @paisT =l.pais
	from Torneo t
	join Locacion l
	on t.locID=l.locID
	where t.torneoID=@idTorneo

	select @cantP=count(i.participanteID)
	from Inscripcion i
	join Torneo t
	on i.torneoID=t.torneoID
	join Locacion l
	on t.locID=l.locID
	where l.pais=@paisT

	return @cantP
end;

select dbo.participantesPais(3)as cantidad_Participantes--torneo 3,8 comparten pais(MEX) ambos tienen 4 inscripciones


--RETORNA EL NOMBRE DEL KITER QUE MAS GANO EN UN RANGO DE FECHAS
create or alter procedure sp_ganadorFechas
	@fechaUno date,
	@fechaDos date,
	@tipoT varchar(50),
	@nombreGanador varchar(100)output

as
begin
	set @nombreGanador=null
	set @nombreGanador=(

	select top 1
	p.nombre
				
	from Participante p
	join Inscripcion i
	on p.participanteID=i.participanteID
	join Torneo t
	on i.torneoID=t.torneoID
	join puesto_puntos pp
	on i.posicion=pp.puesto

	where t.tipo=@tipoT
	and t.fecha between @fechaUno and @fechaDos
	group by p.nombre 
	order by sum(pp.puntos) desc)
			
end

declare @nombreG varchar(100)
exec sp_ganadorFechas '2016/01/01','2024/12/31','kite-surf',@nombreG output
print 'El participante que mas torneos gano fue: '
print  @nombreG--Devuelve el participante 4 que tiene dos primeros puestos

--RETORNA LOS KITERS ANOTADOS AL TORNEO SI ESTE ESTA FINALIZADO
create or alter procedure sp_torneosFinalizadosKiters
	@torneoID int
	as 
	begin
		declare @torneoFinalizado int
		set @torneoFinalizado=(select case when t.estado = 'finalizado' then 1 else 0 end
							from Torneo t
							where t.torneoID=@torneoID)
		if @torneoFinalizado =0
			begin 
				print 'El torneo ingresado no esta finalizado'
				return
			end

		declare @ciudad varchar(100)
		set @ciudad=(select top 1 l.ciudad from Locacion l join Torneo t on l.locID=t.locID where t.torneoID=@torneoID)
		select p.*, l.ciudad
		from  Participante p
		join Inscripcion i on p.participanteID=i.participanteID
		join Torneo t on i.torneoID=t.torneoID
		join Locacion l on p.locID=l.locID
		where t.torneoID=@torneoID
		and l.ciudad <> @ciudad

	end

EXEC sp_torneosFinalizadosKiters 5

