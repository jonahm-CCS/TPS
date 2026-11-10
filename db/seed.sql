-- Synthetic initial records only. Safe to rerun; never overwrites edited records.
begin;
insert into public.production_areas (id,name,code,icon) values
('weld','Weld Shop','WELDSHOP','⌁'),
('cut','Laser & Waterjet','CUTTING','⌗'),
('machine','Machining','CNC / MANUAL','⊞'),
('form','Forming','PRESS BRAKE','⌑'),
('paint','Paint & Finishing','FINISHING','◫'),
('assembly','Assembly & QA','ASSEMBLY / QA','◇') on conflict do nothing;
insert into public.employees (id,name,area,shift,badge,need) values
('jonah','Jonah Mericle','weld',1,'TPS-1001',false),
('marcus','Marcus Reed','weld',1,'TPS-1002',false),
('daniel','Daniel Brooks','weld',1,'TPS-1003',true),
('luis','Luis Martinez','weld',2,'TPS-1004',false),
('eric','Eric Hayes','weld',2,'TPS-1005',true),
('alex','Alex Turner','cut',1,'TPS-1006',false),
('sam','Sam Parker','machine',1,'TPS-1007',false),
('riley','Riley Cole','form',2,'TPS-1008',false),
('jordan','Jordan Lee','paint',1,'TPS-1009',false),
('casey','Casey Morgan','assembly',2,'TPS-1010',false) on conflict do nothing;
insert into public.jobs (id,title,part,customer,revision,material,qty,priority,due) values
('74812','Equipment support frame','6986932-WELD','Demo customer A','A','6061-T6 aluminum',12,'High','2026-11-12'),
('74819','Mounting bracket assembly','6982833-9','Demo customer B','C','A36 steel',24,'Normal','2026-11-13'),
('74826','Enclosure weldment','TM-4206','Demo customer C','B','304 stainless steel',8,'High','2026-11-12'),
('74831','Base plate assembly','TM-6102','Demo customer A','A','A36 steel',16,'Normal','2026-11-16'),
('74835','Guard frame','TM-1830','Demo customer D','D','6061-T6 aluminum',6,'Normal','2026-11-17'),
('74840','Access panel blanks','TM-2240','Demo customer B','A','A36 steel',40,'Normal','2026-11-13'),
('74842','Drive housing','TM-3180','Demo customer C','B','6061-T6 aluminum',10,'High','2026-11-12'),
('74843','Formed channel','TM-5080','Demo customer A','A','A36 steel',30,'Normal','2026-11-16'),
('74845','Panel finish','TM-2200','Demo customer B','A','A36 steel',20,'Normal','2026-11-13'),
('74848','Control cabinet','TM-9010','Demo customer D','C','Assembly',4,'Normal','2026-11-18') on conflict do nothing;
insert into public.operations (job_id,area,employee,status,done,operation,notes) values
('74812','weld','jonah','In progress',4,'Weld assembly','Review the approved drawing and work instructions before beginning. Demo instructions only.'),
('74819','weld','marcus','In progress',10,'Weld assembly','Verify kit quantities and drawing revision before starting.'),
('74826','weld',null,'Ready',0,'Weld assembly','Kit staged in the Weld Shop. Confirm fit-up with the team lead.'),
('74831','weld','luis','Assigned',0,'Weld assembly','Assigned to second shift. Review traveler before starting.'),
('74835','weld',null,'Blocked',0,'Weld assembly','Waiting on a missing kit component. Supervisor must release the hold.'),
('74840','cut','alex','In progress',26,'Laser cutting','Sample job.'),
('74842','machine','sam','In progress',3,'CNC mill','Sample job.'),
('74843','form','riley','Assigned',0,'Press brake','Sample job.'),
('74845','paint','jordan','In progress',12,'Powder coating','Sample job.'),
('74848','assembly','casey','Assigned',0,'Assembly / QA','Sample job.') on conflict do nothing;
commit;
