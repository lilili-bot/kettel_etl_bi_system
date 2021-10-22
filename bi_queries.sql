# 1.  daily order amount, order prices
create table if not exists itcast_shop_bi.app_order_total(
    id integer primary key auto_increment, # unique number
    dt date, # date
    total_money double, # total price of all orders
    total_cnt integer   #total order amount
);

# 2. analyse one day order: total price, total amount

insert into app_order_total
select
       NULL,
       substring(createtime,1, 10),
       sum(payPrice) as total_money,
       count(*) as total_cnt
from
     ods_itheima_order_goods t
where substring(createtime,1,10) = '2019-09-05'
group by substring(createtime,1, 10);

# 3. analyse user distribution on specific day.

create table if not exists app_order_user(
    id integer primary key auto_increment,
    dt date,
    total_user_cnt integer
);

insert into app_order_user
select
       null,
       substring(createTime,1,10),
       count(distinct userId) as user_amount
from ods_orders
where substring(createTime,1,10) = '2019-09-05'
group by substring(createTime,1,10);

# 4. analyse on specific day, different payment method and its order amounts.

create table if not exists app_order_type(
    id integer primary key auto_increment,
    dt date,
    pay_type varchar(20),
    total_money double,
    total_cnt integer
);

select * from ods_orders limit 0,5;
insert into app_order_type
select
       null,
       substr(createTime,1,10),
       case when payType = 1 then 'alipay'
           when payType = 2 then 'wechat'
               when payType = 3 then 'credit_card'
                   else 'others'
       end as payType,
       sum(realTotalMoney) as total_money,
       count(*) as total_cnt
from
     ods_orders
where
      substr(createTime,1,10) = '2019-09-05'
group by
         substr(createTime,1,10),
         payType;

# 5. the highest oder in september.

create table if not exists app_order_top5_users(
    id integer primary key auto_increment,
    dt varchar(20),
    userid varchar(20),
    username varchar(50),
    total_cnt integer
);



insert into app_order_top5_users
select
       null,
       dt,
       userid,
       userName,
       total_cnt
from(select *,rank() over (order by t.total_cnt desc ) as rk
from(
    select
           null,
           '2019-09' dt,
           userId,
           userName,
           count(orderId) total_cnt
    from
         ods_orders
    where substr(createTime,1,7) = '2019-09'
    group by userId, userName,substr(createTime,1,7))
    t
    )
    tt
where tt.rk<=5;

# 6. calculate total order amount and prices of different goods category.

# step 6.1 create a table to store goods and order information.
create table if not exists app_order_goods_cats(
    id integer primary key auto_increment,
    dt varchar(20),
    cat_name varchar(100),
    total_money double,
    total_num integer
);

# 6.2 create a temp table to store goods and level1, level2, level3 category.
create table if not exists temp_goods_cat(
    id integer primary key auto_increment,
    cat_id_l3 integer,
    cat_name_l3 varchar(100),
    cat_id_l2 integer,
    cat_name_l2 varchar(100),
    cat_id_l1 integer,
    cat_name_l1 varchar(100)
);
# 6.3 insert information into the temp table.
insert into temp_goods_cat
select
       null,
       t3.catId as cat_id_l3,
       t3.catName as cat_name_l3,
       t2.catId as cat_id_l2,
       t2.catName as cat_name_l2,
       t1.catId as cat_id_l1,
       t1.catName as cat_name_l1
from ods_itheima_goods_cats as t3, ods_itheima_goods_cats as t2, ods_itheima_goods_cats as t1
where t3.parentId = t2.catId
  and
      t2.parentId = t1.catId
  and
      t3.cat_level = 3;
# 6.4 left join 3 tables to combine goods category with theirs order information(total price, total order numbers)
select
       '2019-09-05',
       a.cat_name_l1 goodName,
       sum(c.payPrice) total_money,
       count(distinct c.orderId) total_num
from
     temp_goods_cat a
         left join ods_itheima_goods b on a.cat_id_l3 = b.goodsCatId
         left join ods_itheima_order_goods c on b.goodsId = c.goodsId
where substr(c.createTime,1,10) = '2019-09-05'
group by a.cat_id_l1, a.cat_name_l1;

# 6.5 to optimize sql query. Set index for columns: temp_goods_cat.cat_id_l3, ods_itheima_goods.goodsCatId, ods_itheima_goods.goodsId, ods_itheima_order_goods.goodsId

create unique index idx_goods_l3 on temp_goods_cat(cat_id_l3);
create index idx_goods_catId on ods_itheima_goods(goodsCatId);
create index idx_goods_id on ods_itheima_goods(goodsId);
create index idx_order_goodsId on ods_itheima_order_goods(goodsId);

# 6.6 rewrite sql query.
#21 rows affected in 155 ms.
insert into app_order_goods_cats
select
       null,
       '2019-09-05',
       a.cat_name_l1 goodName,
       sum(c.payPrice) total_money,
       count(distinct c.orderId) total_num
from
     temp_goods_cat a
         left join ods_itheima_goods b on a.cat_id_l3 = b.goodsCatId
         left join ods_itheima_order_goods c on b.goodsId = c.goodsId
where substr(c.createTime,1,10) = '2019-09-05'
group by a.cat_id_l1, a.cat_name_l1;

