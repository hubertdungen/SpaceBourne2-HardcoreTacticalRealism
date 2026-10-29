"""Render CUE4Parse Blueprint JSON dumps as compact pseudo-code.

usage: kis.py <dump.json> [function-name-regex]   (prints to stdout)
       kis.py --all <dumpdir> <outdir>             (one .txt per package)
"""
import json, os, re, sys


def oname(o):
    if not isinstance(o, dict):
        return str(o)
    n = o.get('ObjectName') or o.get('Name') or '?'
    m = re.match(r"^\w+'(.*)'$", n)
    return m.group(1) if m else n


def prop(p):
    if not isinstance(p, dict):
        return str(p)
    if 'Property' in p:
        pr = p['Property']
        if isinstance(pr, dict):
            return pr.get('Name', '?')
        return str(pr)
    if 'Path' in p:
        return '.'.join(str(x) for x in p['Path'])
    return p.get('Name', '?')


def fn_name(f):
    n = oname(f)
    return n.split(':')[-1] if ':' in n else n


def E(e):
    if e is None:
        return 'None'
    if not isinstance(e, dict):
        return str(e)
    t = e.get('Token', '')
    if t in ('EX_LocalVariable', 'EX_InstanceVariable', 'EX_LocalOutVariable', 'EX_DefaultVariable',
             'EX_ClassSparseDataVariable'):
        n = prop(e.get('Variable'))
        return ('self.' if t == 'EX_InstanceVariable' else '') + n
    if t in ('EX_IntConst', 'EX_FloatConst', 'EX_ByteConst', 'EX_IntConstByte', 'EX_Int64Const', 'EX_UInt64Const'):
        return str(e.get('Value'))
    if t in ('EX_StringConst', 'EX_UnicodeStringConst'):
        return json.dumps(e.get('Value'))
    if t == 'EX_NameConst':
        return "N'" + str(e.get('Value')) + "'"
    if t == 'EX_TextConst':
        v = e.get('Value', {})
        return 'T' + json.dumps(v.get('SourceString', v) if isinstance(v, dict) else v)[:80]
    if t == 'EX_ObjectConst':
        return 'Obj<' + oname(e.get('Value')) + '>'
    if t == 'EX_IntZero': return '0'
    if t == 'EX_IntOne': return '1'
    if t == 'EX_True': return 'true'
    if t == 'EX_False': return 'false'
    if t == 'EX_NoObject': return 'null'
    if t == 'EX_NoInterface': return 'nullIface'
    if t == 'EX_Self': return 'self'
    if t == 'EX_Nothing': return 'nothing'
    if t == 'EX_VectorConst':
        v = e.get('Value', {}); return 'Vec(%s,%s,%s)' % (v.get('X'), v.get('Y'), v.get('Z'))
    if t == 'EX_RotationConst':
        v = e.get('Value', {}); return 'Rot(%s,%s,%s)' % (v.get('Pitch'), v.get('Yaw'), v.get('Roll'))
    if t in ('EX_FinalFunction', 'EX_LocalFinalFunction', 'EX_CallMath', 'EX_CallMulticastDelegate'):
        args = ', '.join(E(a) for a in e.get('Parameters', []))
        f = e.get('Function') or e.get('StackNode')
        return f'{fn_name(f)}({args})'
    if t in ('EX_VirtualFunction', 'EX_LocalVirtualFunction'):
        args = ', '.join(E(a) for a in e.get('Parameters', []))
        name = e.get('VirtualFunctionName') or e.get('Function')
        if isinstance(name, dict):
            name = fn_name(name)
        return f"{name}({args})"
    if t in ('EX_Context', 'EX_Context_FailSilent', 'EX_ClassContext'):
        return f"{E(e.get('ObjectExpression'))}.{E(e.get('ContextExpression'))}"
    if t == 'EX_InterfaceContext':
        return E(e.get('InterfaceValue'))
    if t == 'EX_StructMemberContext':
        return f"{E(e.get('StructExpression'))}.{prop(e.get('Property'))}"
    if t in ('EX_DynamicCast', 'EX_MetaCast', 'EX_ObjToInterfaceCast', 'EX_CrossInterfaceCast', 'EX_InterfaceToObjCast'):
        return f"Cast<{oname(e.get('ClassPtr'))}>({E(e.get('Target'))})"
    if t == 'EX_PrimitiveCast':
        return f"{e.get('ConversionType')}({E(e.get('Target'))})"
    if t == 'EX_ArrayGetByRef':
        return f"{E(e.get('ArrayVariable'))}[{E(e.get('ArrayIndex'))}]"
    if t == 'EX_SwitchValue':
        cases = '; '.join(f"{E(c.get('CaseIndexValueTerm'))}=>{E(c.get('CaseTermExpression') or c.get('CaseTerm'))}" for c in e.get('Cases', []))
        return f"switch({E(e.get('IndexTerm'))}){{{cases}; default=>{E(e.get('DefaultTerm'))}}}"
    if t == 'EX_StructConst':
        vals = ', '.join(E(x) for x in e.get('Properties', e.get('Value', [])) or [])
        return f"{oname(e.get('Struct'))}{{{vals}}}"
    if t in ('EX_SetArray', 'EX_ArrayConst', 'EX_SetSet', 'EX_SetMap', 'EX_SetConst', 'EX_MapConst'):
        els = ', '.join(E(x) for x in e.get('Elements', []) or [])
        tgt = e.get('AssigningProperty')
        return (E(tgt) + ' = ' if tgt else '') + '[' + els + ']'
    if t in ('EX_SoftObjectConst', 'EX_FieldPathConst'):
        return 'Soft<' + E(e.get('Value')) + '>'
    if t == 'EX_PropertyConst':
        return 'Prop<' + prop(e.get('Property')) + '>'
    if t == 'EX_SkipOffsetConst':
        return 'skip@' + str(e.get('Value'))
    if t == 'EX_InstanceDelegate':
        return 'Delegate<' + str(e.get('FunctionName')) + '>'
    # generic fallback
    parts = []
    for k, v in e.items():
        if k in ('Token', 'StatementIndex'):
            continue
        if isinstance(v, dict) and 'Token' in v:
            parts.append(f'{k}={E(v)}')
        elif isinstance(v, list):
            parts.append(f"{k}=[{', '.join(E(x) for x in v)}]")
        elif isinstance(v, dict):
            parts.append(f'{k}={oname(v) if "ObjectName" in v else prop(v)}')
        else:
            parts.append(f'{k}={v}')
    return f"{t[3:]}({', '.join(parts)})"


def S(e):
    t = e.get('Token', '')
    if t in ('EX_Let', 'EX_LetObj', 'EX_LetBool', 'EX_LetWeakObjPtr', 'EX_LetDelegate', 'EX_LetMulticastDelegate'):
        return f"{E(e.get('Variable'))} = {E(e.get('Assignment') or e.get('Expression'))}"
    if t == 'EX_LetValueOnPersistentFrame':
        return f"frame.{prop(e.get('DestinationProperty'))} = {E(e.get('AssignmentExpression'))}"
    if t == 'EX_JumpIfNot':
        return f"if not ({E(e.get('BooleanExpression'))}) goto {e.get('CodeOffset')}"
    if t == 'EX_Jump':
        return f"goto {e.get('CodeOffset')}"
    if t == 'EX_PushExecutionFlow':
        return f"push {e.get('PushingAddress')}"
    if t == 'EX_PopExecutionFlow':
        return 'pop'
    if t == 'EX_PopExecutionFlowIfNot':
        return f"pop if not ({E(e.get('BooleanExpression'))})"
    if t == 'EX_ComputedJump':
        return f"goto *{E(e.get('CodeOffsetExpression'))}"
    if t == 'EX_Return':
        return 'return ' + E(e.get('ReturnExpression') or e.get('Expression'))
    if t == 'EX_EndOfScript':
        return 'END'
    if t in ('EX_AddMulticastDelegate', 'EX_RemoveMulticastDelegate'):
        return f"{E(e.get('Delegate'))} {'+=' if 'Add' in t else '-='} {E(e.get('DelegateToAdd'))}"
    if t == 'EX_BindDelegate':
        return f"{E(e.get('Delegate'))} = bind({e.get('FunctionName')}, {E(e.get('ObjectTerm'))})"
    return E(e)


def render_fn(fn, out):
    params = []
    for p in fn.get('ChildProperties', []) or []:
        flags = p.get('PropertyFlags', '')
        if 'Parm' in flags:
            kind = 'out ' if 'OutParm' in flags and 'ReferenceParm' not in flags else ''
            if 'ReturnParm' in flags: kind = 'ret '
            ty = p.get('Type', '').replace('Property', '')
            sub = p.get('PropertyClass') or p.get('Struct') or p.get('Enum') or {}
            if sub: ty += '<' + oname(sub) + '>'
            params.append(f"{kind}{p.get('Name')}:{ty}")
    out.append(f"\n=== {fn.get('Name')}({', '.join(params)})  [{fn.get('FunctionFlags', '')}]")
    for st in fn.get('ScriptBytecode', []) or []:
        out.append(f"  {st.get('StatementIndex', ''):>6}: {S(st)}")


def render_pkg(path, pat=None):
    data = json.load(open(path, encoding='utf-8'))
    out = []
    for ex in data:
        if not isinstance(ex, dict):
            continue
        t = ex.get('Type')
        if t == 'Function':
            if pat and not re.search(pat, ex.get('Name', ''), re.I):
                continue
            render_fn(ex, out)
        elif t == 'BlueprintGeneratedClass' and not pat:
            out.append(f"### CLASS {ex.get('Name')} : {oname(ex.get('SuperStruct', {}))}")
            for p in ex.get('ChildProperties', []) or []:
                sub = p.get('PropertyClass') or p.get('Struct') or p.get('Enum') or p.get('Inner', {}).get('PropertyClass') or {}
                out.append(f"  var {p.get('Name')}: {p.get('Type', '').replace('Property', '')}{'<' + oname(sub) + '>' if sub else ''}")
    return '\n'.join(out)


if __name__ == '__main__':
    if sys.argv[1] == '--all':
        src, dst = sys.argv[2], sys.argv[3]
        for root, _, files in os.walk(src):
            for f in files:
                if f.endswith('.json'):
                    p = os.path.join(root, f)
                    rel = os.path.relpath(p, src)[:-len('.uasset.json')] + '.txt'
                    o = os.path.join(dst, rel)
                    os.makedirs(os.path.dirname(o), exist_ok=True)
                    try:
                        txt = render_pkg(p)
                    except Exception as ex:
                        txt = 'RENDER ERROR ' + repr(ex)
                    open(o, 'w', encoding='utf-8').write(txt)
    else:
        sys.stdout.reconfigure(encoding='utf-8')
        print(render_pkg(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
