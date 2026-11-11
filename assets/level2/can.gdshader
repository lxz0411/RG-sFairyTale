shader_type canvas_item;
void fragment(){
vec2 p=UV*vec2(1280.0,800.0);
bool inside=false;
bool hole=false;
float edge=10000.0;
if (((561.0>p.y)!=(615.0>p.y)) && (p.x<(4.0)*(p.y-561.0)/(54.0)+765.0)) inside=!inside;
{vec2 a=vec2(765.0,561.0); vec2 d=vec2(4.0,54.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((548.0>p.y)!=(561.0>p.y)) && (p.x<(-9.0)*(p.y-548.0)/(13.0)+774.0)) inside=!inside;
{vec2 a=vec2(774.0,548.0); vec2 d=vec2(-9.0,13.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((539.0>p.y)!=(548.0>p.y)) && (p.x<(-25.0)*(p.y-539.0)/(9.0)+799.0)) inside=!inside;
{vec2 a=vec2(799.0,539.0); vec2 d=vec2(-25.0,9.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((533.0>p.y)!=(539.0>p.y)) && (p.x<(9.0)*(p.y-533.0)/(6.0)+790.0)) inside=!inside;
{vec2 a=vec2(790.0,533.0); vec2 d=vec2(9.0,6.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((521.0>p.y)!=(533.0>p.y)) && (p.x<(-7.0)*(p.y-521.0)/(12.0)+797.0)) inside=!inside;
{vec2 a=vec2(797.0,521.0); vec2 d=vec2(-7.0,12.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((510.0>p.y)!=(521.0>p.y)) && (p.x<(-34.0)*(p.y-510.0)/(11.0)+831.0)) inside=!inside;
{vec2 a=vec2(831.0,510.0); vec2 d=vec2(-34.0,11.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((509.0>p.y)!=(510.0>p.y)) && (p.x<(-22.0)*(p.y-509.0)/(1.0)+853.0)) inside=!inside;
{vec2 a=vec2(853.0,509.0); vec2 d=vec2(-22.0,1.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((521.0>p.y)!=(509.0>p.y)) && (p.x<(-13.0)*(p.y-521.0)/(-12.0)+866.0)) inside=!inside;
{vec2 a=vec2(866.0,521.0); vec2 d=vec2(-13.0,-12.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((580.0>p.y)!=(521.0>p.y)) && (p.x<(-29.0)*(p.y-580.0)/(-59.0)+895.0)) inside=!inside;
{vec2 a=vec2(895.0,580.0); vec2 d=vec2(-29.0,-59.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((502.0>p.y)!=(580.0>p.y)) && (p.x<(-36.0)*(p.y-502.0)/(78.0)+931.0)) inside=!inside;
{vec2 a=vec2(931.0,502.0); vec2 d=vec2(-36.0,78.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((485.0>p.y)!=(502.0>p.y)) && (p.x<(-2.0)*(p.y-485.0)/(17.0)+933.0)) inside=!inside;
{vec2 a=vec2(933.0,485.0); vec2 d=vec2(-2.0,17.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((488.0>p.y)!=(485.0>p.y)) && (p.x<(-13.0)*(p.y-488.0)/(-3.0)+946.0)) inside=!inside;
{vec2 a=vec2(946.0,488.0); vec2 d=vec2(-13.0,-3.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((505.0>p.y)!=(488.0>p.y)) && (p.x<(-14.0)*(p.y-505.0)/(-17.0)+960.0)) inside=!inside;
{vec2 a=vec2(960.0,505.0); vec2 d=vec2(-14.0,-17.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((512.0>p.y)!=(505.0>p.y)) && (p.x<(14.0)*(p.y-512.0)/(-7.0)+946.0)) inside=!inside;
{vec2 a=vec2(946.0,512.0); vec2 d=vec2(14.0,-7.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((581.0>p.y)!=(512.0>p.y)) && (p.x<(34.0)*(p.y-581.0)/(-69.0)+912.0)) inside=!inside;
{vec2 a=vec2(912.0,581.0); vec2 d=vec2(34.0,-69.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((612.0>p.y)!=(581.0>p.y)) && (p.x<(0.0)*(p.y-612.0)/(-31.0)+912.0)) inside=!inside;
{vec2 a=vec2(912.0,612.0); vec2 d=vec2(0.0,-31.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((621.0>p.y)!=(612.0>p.y)) && (p.x<(12.0)*(p.y-621.0)/(-9.0)+900.0)) inside=!inside;
{vec2 a=vec2(900.0,621.0); vec2 d=vec2(12.0,-9.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((635.0>p.y)!=(621.0>p.y)) && (p.x<(61.0)*(p.y-635.0)/(-14.0)+839.0)) inside=!inside;
{vec2 a=vec2(839.0,635.0); vec2 d=vec2(61.0,-14.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((624.0>p.y)!=(635.0>p.y)) && (p.x<(22.0)*(p.y-624.0)/(11.0)+817.0)) inside=!inside;
{vec2 a=vec2(817.0,624.0); vec2 d=vec2(22.0,11.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((610.0>p.y)!=(624.0>p.y)) && (p.x<(6.0)*(p.y-610.0)/(14.0)+811.0)) inside=!inside;
{vec2 a=vec2(811.0,610.0); vec2 d=vec2(6.0,14.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((622.0>p.y)!=(610.0>p.y)) && (p.x<(31.0)*(p.y-622.0)/(-12.0)+780.0)) inside=!inside;
{vec2 a=vec2(780.0,622.0); vec2 d=vec2(31.0,-12.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((615.0>p.y)!=(622.0>p.y)) && (p.x<(11.0)*(p.y-615.0)/(7.0)+769.0)) inside=!inside;
{vec2 a=vec2(769.0,615.0); vec2 d=vec2(11.0,7.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((565.0>p.y)!=(606.0>p.y)) && (p.x<(7.0)*(p.y-565.0)/(41.0)+779.0)) hole=!hole;
{vec2 a=vec2(779.0,565.0); vec2 d=vec2(7.0,41.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((553.0>p.y)!=(565.0>p.y)) && (p.x<(-17.0)*(p.y-553.0)/(12.0)+796.0)) hole=!hole;
{vec2 a=vec2(796.0,553.0); vec2 d=vec2(-17.0,12.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((598.0>p.y)!=(553.0>p.y)) && (p.x<(-10.0)*(p.y-598.0)/(-45.0)+806.0)) hole=!hole;
{vec2 a=vec2(806.0,598.0); vec2 d=vec2(-10.0,-45.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
if (((606.0>p.y)!=(598.0>p.y)) && (p.x<(20.0)*(p.y-606.0)/(-8.0)+786.0)) hole=!hole;
{vec2 a=vec2(786.0,606.0); vec2 d=vec2(20.0,-8.0); edge=min(edge,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
// Preserve the painted outline; avoid an artificial dark cutout border.
COLOR.a *= (inside && !hole) ? smoothstep(0.1,1.6,edge) : 0.0;
}
