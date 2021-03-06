#include "stdafx.h"
#include "../fmesh.h"
#include "flod.h"

void FLOD::Load			(LPCSTR N, IReader *data, u32 dwFlags)
{
	inherited::Load		(N,data,dwFlags);

	// LOD-def
	R_ASSERT			(data->find_chunk(OGF_LODDEF2));
	for (int f=0; f<8; f++)
	{
		data->r					(facets[f].v,sizeof(facets[f].v));
		_vertex* v				= facets[f].v;

		Fvector					N,T;
		N.set					(0,0,0);
		T.mknormal				(v[0].v,v[1].v,v[2].v);	N.add	(T);
		T.mknormal				(v[1].v,v[2].v,v[3].v);	N.add	(T);
		T.mknormal				(v[2].v,v[3].v,v[0].v);	N.add	(T);
		T.mknormal				(v[3].v,v[0].v,v[1].v);	N.add	(T);
		N.div					(4.f);
		facets[f].N.normalize	(N);
		facets[f].N.invert		();
	}

	// VS
	geom.create			(F_HW, RCache.Vertex.Buffer(), RCache.QuadIB);

	// lod correction
	Fvector3			S;
	vis.box.getradius	(S);
	float r 			= vis.sphere.R;
	std::sort			(&S.x,&S.x+3);
	float a				= S.y;
	float Sf			= 4.f*(0.5f*(r*r*asin(a/r)+a*_sqrt(r*r-a*a)));
	float Ss			= M_PI*r*r;
	lod_factor			= Sf/Ss;
}
void FLOD::Copy			(IRender_Visual *pFrom	)
{
	inherited::Copy		(pFrom);

	FLOD* F				= (FLOD*)pFrom;
	geom				= F->geom		;
	lod_factor			= F->lod_factor	;
	Memory.mem_copy		(facets,F->facets,sizeof(facets));
}
void FLOD::Render		(float LOD)
{
	Fvector				Ldir;
	Ldir.sub			(vis.sphere.P,Device.vCameraPosition);
	Ldir.normalize		();

	int					best_id		= 0;
	float				best_dot	= Ldir.dotproduct(facets[0].N);
	float				dot;

	dot	= Ldir.dotproduct	(facets[1].N); if (dot>best_dot) { best_id=1; best_dot=dot; }
	dot	= Ldir.dotproduct	(facets[2].N); if (dot>best_dot) { best_id=2; best_dot=dot; }
	dot	= Ldir.dotproduct	(facets[3].N); if (dot>best_dot) { best_id=3; best_dot=dot; }
	dot	= Ldir.dotproduct	(facets[4].N); if (dot>best_dot) { best_id=4; best_dot=dot; }
	dot	= Ldir.dotproduct	(facets[5].N); if (dot>best_dot) { best_id=5; best_dot=dot; }
	dot	= Ldir.dotproduct	(facets[6].N); if (dot>best_dot) { best_id=6; best_dot=dot; }
	dot	= Ldir.dotproduct	(facets[7].N); if (dot>best_dot) { best_id=7; best_dot=dot; }

#pragma todo("Smooth transitions")
#pragma todo("5-coloring")

	// Fill VB
	_face&		F					= facets[best_id];
	u32			vOffset				= 0;
	_hw*		V					= (_hw*) RCache.Vertex.Lock(4,geom->vb_stride,vOffset);
	V[0].set	(F.v[0].v,F.N,F.v[0].c_rgb_hemi,F.v[0].t.x,F.v[0].t.y);
	V[1].set	(F.v[1].v,F.N,F.v[1].c_rgb_hemi,F.v[1].t.x,F.v[1].t.y);
	V[2].set	(F.v[2].v,F.N,F.v[2].c_rgb_hemi,F.v[2].t.x,F.v[2].t.y);
	V[3].set	(F.v[3].v,F.N,F.v[3].c_rgb_hemi,F.v[3].t.x,F.v[3].t.y);
	RCache.Vertex.Unlock			(4,geom->vb_stride);

	// Draw IT
	RCache.set_Geometry		(geom);
	RCache.Render			(D3DPT_TRIANGLEFAN,vOffset,2);
}
